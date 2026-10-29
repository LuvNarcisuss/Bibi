import { HTTPError } from "./http.ts";

export function inspectMedia(bytes: Uint8Array, mime: string): { duration: number | null } {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  if (mime === "image/png") {
    const signature = [137,80,78,71,13,10,26,10];
    if (bytes.length < 24 || signature.some((b,i) => bytes[i] !== b)
      || view.getUint32(16) < 1 || view.getUint32(20) < 1
      || view.getUint32(16) > 1200 || view.getUint32(20) > 1200) throw new HTTPError(400, "Invalid image dimensions.");
    return { duration: null };
  }
  if (mime === "image/jpeg") {
    if (bytes.length < 4 || bytes[0] !== 255 || bytes[1] !== 216) throw new HTTPError(400, "Invalid JPEG.");
    let offset = 2;
    while (offset + 4 <= bytes.length) {
      if (bytes[offset] !== 255) break;
      while (bytes[offset] === 255) offset++;
      const marker = bytes[offset++];
      if (marker === 217 || marker === 218) break;
      if (marker === 1 || marker >= 208 && marker <= 215) continue;
      if (offset + 2 > bytes.length) break;
      const length = view.getUint16(offset);
      if (length < 2 || offset + length > bytes.length) break;
      if ([192,193,194].includes(marker)) {
        if (length < 8) break;
        const h = view.getUint16(offset + 3), w = view.getUint16(offset + 5);
        if (h < 1 || w < 1 || h > 1200 || w > 1200) throw new HTTPError(400, "Invalid image dimensions.");
        return { duration: null };
      }
      offset += length;
    }
    throw new HTTPError(400, "Unsupported JPEG.");
  }
  if (mime !== "video/mp4") throw new HTTPError(400, "Unsupported media.");
  const text = (offset: number, length: number) => new TextDecoder().decode(bytes.subarray(offset, offset + length));
  let duration: number | null = null, fileType = false, mediaData = false;
  function atoms(start: number, end: number, depth: number) {
    if (depth > 2) throw new HTTPError(400, "Invalid MP4 structure.");
    for (let offset = start; offset + 8 <= end;) {
      let length = view.getUint32(offset), header = 8;
      const type = text(offset + 4, 4);
      if (length === 1) {
        if (offset + 16 > end) throw new HTTPError(400, "Invalid MP4 atom.");
        const large = view.getBigUint64(offset + 8);
        if (large > BigInt(end - offset)) throw new HTTPError(400, "Invalid MP4 atom.");
        length = Number(large); header = 16;
      } else if (length === 0) length = end - offset;
      if (length < header || offset + length > end) throw new HTTPError(400, "Invalid MP4 atom.");
      const content = offset + header;
      if (type === "ftyp" && depth === 0) fileType = true;
      if (type === "mdat" && depth === 0 && length > header) mediaData = true;
      if (type === "moov") atoms(content, offset + length, depth + 1);
      if (type === "mvhd" && depth === 1) {
        const version = bytes[content];
        const scaleOffset = content + (version === 1 ? 20 : 12);
        const required = version === 1 ? 12 : 8;
        if ((version !== 0 && version !== 1) || scaleOffset + required > offset + length) throw new HTTPError(400, "Invalid MP4 duration.");
        const scale = view.getUint32(scaleOffset);
        const ticks = version === 1 ? Number(view.getBigUint64(scaleOffset + 4)) : view.getUint32(scaleOffset + 4);
        duration = ticks / scale;
      }
      offset += length;
    }
  }
  atoms(0, bytes.length, 0);
  if (!fileType || !mediaData || duration === null || !Number.isFinite(duration) || duration <= 0 || duration > 180) {
    throw new HTTPError(400, "Videos must be valid MP4 files up to three minutes long.");
  }
  return { duration };
}

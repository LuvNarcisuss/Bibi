import { authenticate, body, HTTPError, serve, uuid } from "../_shared/http.ts";
import { inspectMedia } from "../_shared/media.ts";

serve(async request => {
  const { db, user } = await authenticate(request);
  const input = await body(request);
  const id = uuid(input.media_id);
  const { data: media, error } = await db.from("bibi_media").select("*").eq("id", id).eq("owner_id", user.id).single();
  if (error || !media || media.status === "removed") throw new HTTPError(404, "Upload not found.");
  // Only the server-constructed private path is fetched, never a user-supplied URL.
  const { data: object, error: downloadError } = await db.storage.from(media.bucket_id).download(media.object_path);
  if (downloadError || !object) throw new HTTPError(409, "Upload is not complete.");
  const limit = media.bucket_id === "bibi-images" ? 1_000_000 : 50_000_000;
  if (object.size < 1 || object.size > limit) throw new HTTPError(413, "File exceeds the upload limit.");
  const bytes = new Uint8Array(await object.arrayBuffer());
  const inspected = inspectMedia(bytes, media.mime_type);
  const { data, error: finalError } = await db.rpc("bibi_finalize_media", {
    p_user: user.id, p_media: id, p_size: bytes.length, p_mime: media.mime_type, p_duration: inspected.duration,
  });
  if (finalError) throw new HTTPError(409, "Upload could not be finalized.");
  return data;
});

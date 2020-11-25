import { ServerRequest } from "https://deno.land/std@0.75.0/http/server.ts";
import { Hash } from "https://deno.land/x/checksum@1.4.0/hash.ts";
import { endpoint, ensurePost, parseBody } from "./utils.ts";

// Other functions can import this function to call this serverless endpoint
export const uploadEndpoint = async (url: string) => {
  const response = await fetch("https://cdn.hackclub.com/api/v2/upload", {
    method: "POST",
    body: url,
  });
  const result = await response.json();

  return result;
};

const upload = async (url: string) => {
  const req = await fetch(url);
  const reqArrayBuffer = await req.arrayBuffer();
  const data = new Uint8Array(reqArrayBuffer);
  const sha = new Hash("sha1").digest(data).hex();
  const size = data.byteLength;

  await fetch(endpoint("v2/now/files"), {
    method: "POST",
    headers: {
      "Content-Length": size.toString(),
      "x-now-digest": sha,
      "Authorization": `Bearer ${Deno.env.get("ZEIT_TOKEN")}`,
    },
    body: data.buffer,
  });

  return {
    url,
    sha,
    size,
  };
};

export default async (req: ServerRequest) => {
  if (!ensurePost(req)) return null;

  const body = await parseBody(req.body);
  const uploadedFileUrl = await upload(body);

  req.respond({ body: JSON.stringify(uploadedFileUrl) });
};

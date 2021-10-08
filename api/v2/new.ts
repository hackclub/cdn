import { ServerRequest } from "https://deno.land/std@0.75.0/http/server.ts";
import { urlParse } from "https://deno.land/x/url_parse/mod.ts";
import { uploadEndpoint } from "./upload.ts";
import { deployEndpoint } from "./deploy.ts";
import { ensurePost, parseBody } from "./utils.ts";

export default async (req: ServerRequest) => {
  if (!ensurePost(req)) return null;

  const body = await parseBody(req.body);
  const fileURLs = JSON.parse(body);

  if (!Array.isArray(fileURLs) || fileURLs.length < 1) {
    return req.respond(
      {
        status: 422,
        body: JSON.stringify({ error: "Empty/invalid file array" }),
      },
    );
  }

  const authorization = req.headers.get('Authorization')

  const uploadArray = await Promise.all(fileURLs.map(f => uploadEndpoint(f, authorization)));

  const deploymentFiles = uploadArray.map(
    (file: { url: string; sha: string; size: number }, index: number) => {
      const { pathname } = urlParse(file.url);
      const filename = index + pathname.substr(pathname.lastIndexOf("/") + 1);
      return { sha: file.sha, file: filename, size: file.size };
    },
  );

  const deploymentData = await deployEndpoint(deploymentFiles);

  req.respond(
    {
      body: JSON.stringify(deploymentData.files),
      status: deploymentData.status,
    },
  );
};

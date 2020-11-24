import { endpoint } from "./utils.ts";

// Other functions can import this function to call this serverless endpoint
export const deployEndpoint = async (
  files: { sha: string; file: string; size: number }[],
) => {
  return await deploy(files);
};

const deploy = async (
  files: { sha: string; file: string; size: number }[],
) => {
  const req = await fetch(endpoint("v12/now/deployments"), {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${Deno.env.get("ZEIT_TOKEN")}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      name: "cloud",
      files: files.map((f) => ({
        sha: f.sha,
        file: f.file,
        size: f.size,
      })),
      projectSettings: {
        framework: null,
      },
    }),
  });
  const json = await req.json();
  const deployedFiles = files.map((file) => ({
    deployedUrl: `https://${json.url}/public/${file.file}`,
    ...file,
  }));

  return { status: req.status, files: deployedFiles };
};

export default deploy;

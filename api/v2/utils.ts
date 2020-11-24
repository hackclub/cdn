import { ServerRequest } from "https://deno.land/std@0.75.0/http/server.ts";

export const endpoint = (path: string) => {
  // https://vercel.com/docs/api#api-basics/authentication/accessing-resources-owned-by-a-team
  let url = "https://api.vercel.com/" + path;
  if (Deno.env.get("ZEIT_TEAM")) {
    url += ("?teamId=" + Deno.env.get("ZEIT_TEAM"));
  }
  return url;
};

export const parseBody = async (body: ServerRequest["body"]) => {
  const decoder = new TextDecoder();
  const buf = await Deno.readAll(body);
  const result = decoder.decode(buf);
  return result;
};

export const ensurePost = (req: ServerRequest) => {
  if (req.method == "OPTIONS") {
    req.respond(
      {
        status: 204,
        body: JSON.stringify(
          { status: "YIPPE YAY. YOU HAVE CLEARANCE TO PROCEED." },
        ),
      },
    );
    return false;
  }
  if (req.method == "GET") {
    req.respond(
      {
        status: 405,
        body: JSON.stringify(
          { error: "*GET outta here!* (Method not allowed, use POST)" },
        ),
      },
    );
    return false;
  }
  if (req.method == "PUT") {
    req.respond(
      {
        status: 405,
        body: JSON.stringify(
          { error: "*PUT that request away!* (Method not allowed, use POST)" },
        ),
      },
    );
    return false;
  }
  if (req.method != "POST") {
    req.respond(
      {
        status: 405,
        body: JSON.stringify({ error: "Method not allowed, use POST" }),
      },
    );
    return false;
  }
  return true;
};

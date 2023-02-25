export const endpoint = (path: string) => {
  // https://vercel.com/docs/api#api-basics/authentication/accessing-resources-owned-by-a-team
  let url = "https://api.vercel.com/" + path;
  if (Deno.env.get("ZEIT_TEAM")) {
    url += ("?teamId=" + Deno.env.get("ZEIT_TEAM"));
  }
  return url;
};

export const parseBody = async (body: Request["body"]) => {
  const decoder = new TextDecoder();
  const buf = await Deno.readAll(body);
  const result = decoder.decode(buf);
  return result;
};

export const ensurePost = (req: Request) => {
  if (req.method == "OPTIONS") {
    return new Response(
      JSON.stringify(
        { status: "YIPPE YAY. YOU HAVE CLEARANCE TO PROCEED." },
      ),
      {
        status: 204
      },
    );
  }
  if (req.method == "GET") {
    return new Response(
      JSON.stringify(
        { error: "*GET outta here!* (Method not allowed, use POST)" },
      ),
      {
        status: 405
      },
    );
  }
  if (req.method == "PUT") {
    return new Response(
      JSON.stringify(
        { error: "*PUT that request away!* (Method not allowed, use POST)" },
      ),
      {
        status: 405,
      },
    );
  }
  if (req.method != "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed, use POST" }),
      {
        status: 405,
      },
    );
  }
  return true;
};

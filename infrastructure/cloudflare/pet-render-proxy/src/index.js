const MODEL = "@cf/black-forest-labs/flux-2-klein-4b";
const DEFAULT_WIDTH = 1024;
const DEFAULT_HEIGHT = 1024;
const MAX_PROMPT_CHARS = 16000;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/health") {
      return json({
        ok: true,
        service: "petverse-render-proxy",
        model: MODEL,
      });
    }

    if (
      request.method !== "POST" ||
      !["/v1/render/initial", "/v1/render/evolution"].includes(url.pathname)
    ) {
      return json({ ok: false, error: "Not found" }, 404);
    }

    if (env.PETVERSE_PROXY_KEY) {
      const supplied = request.headers.get("X-PetVerse-Key") || "";

      if (supplied !== env.PETVERSE_PROXY_KEY) {
        return json({ ok: false, error: "Unauthorized" }, 401);
      }
    }

    const contentType = request.headers.get("content-type") || "";

    if (!contentType.includes("application/json")) {
      return json(
        { ok: false, error: "Expected application/json" },
        415
      );
    }

    let input;

    try {
      input = await request.json();
    } catch {
      return json({ ok: false, error: "Invalid JSON" }, 400);
    }

    const prompt = String(input?.prompt || "").trim();

    if (!prompt) {
      return json({ ok: false, error: "Missing prompt" }, 400);
    }

    if (prompt.length > MAX_PROMPT_CHARS) {
      return json({ ok: false, error: "Prompt too long" }, 413);
    }

    const width = clampDimension(
      input?.width,
      DEFAULT_WIDTH
    );
    const height = clampDimension(
      input?.height,
      DEFAULT_HEIGHT
    );
    const seed = normalizeSeed(
      input?.seed
    );

    let reference = null;
    if (url.pathname === "/v1/render/evolution") {
      const encoded = input?.source_image;
      if (typeof encoded !== "string" || !encoded || encoded.length > 4_000_000) {
        return json({ ok: false, error: "Invalid source image" }, 400);
      }
      try {
        const binary = atob(encoded);
        const bytes = Uint8Array.from(binary, c => c.charCodeAt(0));
        if (bytes.length < 24 || bytes[0] !== 137 || bytes[1] !== 80 || bytes[2] !== 78 || bytes[3] !== 71) {
          throw new Error("Expected PNG");
        }
        const view = new DataView(bytes.buffer);
        if (view.getUint32(16) >= 512 || view.getUint32(20) >= 512) {
          throw new Error("Reference must be smaller than 512 pixels");
        }
        reference = new Blob([bytes], { type: "image/png" });
      } catch {
        return json({ ok: false, error: "Invalid reference PNG" }, 400);
      }
    }

    try {
      const form = new FormData();
      if (reference) form.append("input_image_0", reference, "previous-pet.png");
      form.append("prompt", prompt);
      form.append("width", String(width));
      form.append("height", String(height));
      if (seed !== null) form.append("seed", String(seed));

      const formResponse = new Response(form);
      const formContentType =
        formResponse.headers.get("content-type");

      const result = await env.AI.run(MODEL, {
        multipart: {
          body: formResponse.body,
          contentType: formContentType,
        },
      });

      const image = String(result?.image || "");

      if (!image) {
        return json(
          { ok: false, error: "Workers AI returned no image" },
          502
        );
      }

      return json({
        ok: true,
        image,
        model: MODEL,
        width,
        height,
        seed,
      });
    } catch (error) {
      return json(
        {
          ok: false,
          error:
            error instanceof Error
              ? error.message
              : "Workers AI request failed",
        },
        502
      );
    }
  },
};

function normalizeSeed(value) {
  if (value === undefined || value === null || value === "") {
    return null;
  }

  const parsed = Number(value);

  if (!Number.isSafeInteger(parsed) || parsed < 1 || parsed > 2147483646) {
    return null;
  }

  return parsed;
}

function clampDimension(value, fallback) {
  const parsed = Number(value);

  if (!Number.isFinite(parsed)) {
    return fallback;
  }

  return Math.min(1920, Math.max(256, Math.round(parsed)));
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

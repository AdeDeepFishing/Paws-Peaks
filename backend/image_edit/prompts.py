"""Reference-image editing instructions and item-description formatting."""

STYLE_PROMPT = ("Turn this rough sketch into a clear, three-dimensional reference of the "
                "object described below. Preserve its silhouette and proportions. "
                "The original sketch is the authority for shape and pose if the description conflicts with it. "
                "Keep exactly its orientation, endpoint positions and viewpoint. "
                "Do not turn a diagonal object upright or substitute a conventional product pose. "
                "Do not rotate, mirror, flip, straighten or reorient the object. "
                "Preserve the relative arrangement of its parts; only uniform scaling and "
                "translation are allowed to fit the margins. "
                "Hand-drawing style, isolated object on a fully transparent background, no text. "
                "Return only the object with transparent pixels around it. No white backdrop, checkerboard pattern, floor, scenery, or cast shadow. Show one complete object in a single view, not a collage. "
                "Fit the entire object inside the frame with at least 10% empty margin on every side. "
                "All endpoints, rails, handles and other parts must be fully visible. "
                "No cropping, cut-off parts, close-up framing or objects touching the image edges. "
                "Zoom out as needed; preserve the complete object's proportions.")


def reference_prompt(item, style):
    return (style + "\nObject description: " + item["name"] + ". " + item["description"]
            + "\nMaterial: " + item["texture_key"] + ". Use " + item["color"]
            + " as the dominant base color across the whole object, matching the game's material tint. "
            "Use this supplied color even if the sketch or description suggests other colors. "
            "Keep a simple, muted storybook style. "
            "Avoid contrasting colors on separate parts; keep the object mostly one color."
            + "\nUse simple solid forms with minimal shading. No fine surface detail, "
            "decorative textures, scenery, labels or extra objects. Prioritize readable geometry.")

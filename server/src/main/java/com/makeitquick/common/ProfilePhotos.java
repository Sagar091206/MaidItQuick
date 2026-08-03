package com.makeitquick.common;

import java.util.Base64;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Validates and normalizes avatar/profile photo payloads sent by the mobile
 * app as base64 data URIs, for example
 * {@code data:image/jpeg;base64,/9j/4AAQ...}.
 */
public final class ProfilePhotos {

    /** Maximum decoded image size accepted, in bytes. */
    public static final int MAX_BYTES = 2_000_000;

    private static final Pattern DATA_URI =
            Pattern.compile("^data:image/(jpeg|png|webp);base64,([A-Za-z0-9+/=\\r\\n\\s]+)$");

    private ProfilePhotos() {
    }

    /**
     * Verifies the payload is a supported base64 image data URI and returns
     * it trimmed. Returns {@code null} when the input is blank.
     *
     * @throws IllegalArgumentException with a user-safe message when invalid
     */
    public static String normalize(String raw) {
        if (raw == null || raw.isBlank()) return null;
        String compact = raw.trim();
        Matcher matcher = DATA_URI.matcher(compact);
        if (!matcher.matches()) {
            throw new IllegalArgumentException("Upload a JPG, PNG or WebP photo.");
        }
        String base64 = matcher.group(2).replaceAll("\\s+", "");
        byte[] decoded;
        try {
            decoded = Base64.getDecoder().decode(base64);
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("The photo is corrupted. Choose it again.");
        }
        if (decoded.length == 0 || decoded.length > MAX_BYTES) {
            throw new IllegalArgumentException("The photo must be smaller than 2 MB.");
        }
        return compact;
    }
}

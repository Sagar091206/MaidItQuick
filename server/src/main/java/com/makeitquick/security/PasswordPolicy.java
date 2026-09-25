package com.makeitquick.security;

import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.util.regex.Pattern;

/**
 * Enforces the platform password policy for password reset:
 * - Minimum 8 characters (up to 128)
 * - At least 1 uppercase letter (A-Z)
 * - At least 1 lowercase letter (a-z)
 * - At least 1 number (0-9)
 * - At least 1 special character (!@#$%^&*)
 */
public final class PasswordPolicy {

    public static final String REGEX = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[!@#$%^&*]).{8,128}$";
    public static final String ERROR_MESSAGE =
            "Password must be at least 8 characters and contain at least 1 uppercase letter (A-Z), 1 lowercase letter (a-z), 1 number (0-9), and 1 special character (!@#$%^&*)";

    private static final Pattern PATTERN = Pattern.compile(REGEX);
    private static final Pattern UPPERCASE = Pattern.compile("[A-Z]");
    private static final Pattern LOWERCASE = Pattern.compile("[a-z]");
    private static final Pattern DIGIT = Pattern.compile("[0-9]");
    private static final Pattern SPECIAL = Pattern.compile("[!@#$%^&*]");

    private PasswordPolicy() {}

    public static boolean hasMinLength(String password) {
        return password != null && password.length() >= 8 && password.length() <= 128;
    }

    public static boolean hasUppercase(String password) {
        return password != null && UPPERCASE.matcher(password).find();
    }

    public static boolean hasLowercase(String password) {
        return password != null && LOWERCASE.matcher(password).find();
    }

    public static boolean hasDigit(String password) {
        return password != null && DIGIT.matcher(password).find();
    }

    public static boolean hasSpecial(String password) {
        return password != null && SPECIAL.matcher(password).find();
    }

    public static boolean isValid(String password) {
        if (password == null) {
            return false;
        }
        return PATTERN.matcher(password).matches();
    }

    public static void validate(String password) {
        if (password == null || password.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Password is required");
        }
        if (password.length() < 8 || password.length() > 128) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Password must be between 8 and 128 characters");
        }
        if (!hasUppercase(password)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Password must contain at least 1 uppercase letter (A-Z)");
        }
        if (!hasLowercase(password)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Password must contain at least 1 lowercase letter (a-z)");
        }
        if (!hasDigit(password)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Password must contain at least 1 number (0-9)");
        }
        if (!hasSpecial(password)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Password must contain at least 1 special character (!@#$%^&*)");
        }
    }
}

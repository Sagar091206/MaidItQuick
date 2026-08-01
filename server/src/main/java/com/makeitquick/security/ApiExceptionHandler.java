package com.makeitquick.security;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.ConstraintViolationException;
import java.util.LinkedHashMap;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;

/**
 * Turns every controller failure into a consistent JSON error payload
 * {@code {timestamp, status, error, path, message}} without leaking stack
 * traces or server internals to API clients.
 */
@RestControllerAdvice
public class ApiExceptionHandler {
    private static final Logger log = LoggerFactory.getLogger(ApiExceptionHandler.class);

    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<Map<String, Object>> handleResponseStatus(
            ResponseStatusException ex, HttpServletRequest request) {
        HttpStatusCode status = ex.getStatusCode();
        String message = ex.getReason() != null && !ex.getReason().isBlank()
                ? ex.getReason()
                : "Request failed";
        return respond(status, message, request);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> handleValidation(
            MethodArgumentNotValidException ex, HttpServletRequest request) {
        String message = ex.getBindingResult().getFieldErrors().stream()
                .findFirst()
                .map(FieldError::getDefaultMessage)
                .orElse("Request validation failed");
        return respond(HttpStatus.BAD_REQUEST, message, request);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<Map<String, Object>> handleConstraintViolation(
            ConstraintViolationException ex, HttpServletRequest request) {
        return respond(HttpStatus.BAD_REQUEST, "Request validation failed", request);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<Map<String, Object>> handleUnreadableBody(
            HttpMessageNotReadableException ex, HttpServletRequest request) {
        return respond(HttpStatus.BAD_REQUEST, "Malformed request body", request);
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<Map<String, Object>> handleConflict(
            DataIntegrityViolationException ex, HttpServletRequest request) {
        return respond(HttpStatus.CONFLICT, "Request conflicts with existing data", request);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleUnexpected(
            Exception ex, HttpServletRequest request) {
        log.error("Unhandled error on {}", request.getRequestURI(), ex);
        return respond(HttpStatus.INTERNAL_SERVER_ERROR, "Something went wrong. Try again later.", request);
    }

    private ResponseEntity<Map<String, Object>> respond(
            HttpStatusCode status, String message, HttpServletRequest request) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("timestamp", java.time.Instant.now().toString());
        body.put("status", status.value());
        body.put("error", HttpStatus.resolve(status.value()) == null
                ? "Error" : HttpStatus.resolve(status.value()).getReasonPhrase());
        body.put("path", request.getRequestURI());
        body.put("message", message);
        return ResponseEntity.status(status).body(body);
    }
}

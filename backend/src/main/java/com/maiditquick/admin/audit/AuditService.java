package com.maiditquick.admin.audit;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

@Service
public class AuditService {

    private final AuditLogRepository logs;

    public AuditService(AuditLogRepository logs) {
        this.logs = logs;
    }

    /**
     * Record an audit entry. Runs in its own transaction (REQUIRES_NEW) so the
     * entry is committed even when the surrounding business transaction rolls
     * back — failed attempts must be observable in the trail.
     * adminId is the authenticated actor; recordId is the affected record.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void record(String action, String module, String recordId, String before, String after, HttpServletRequest request) {
        AuditLog l = new AuditLog();
        try {
            l.setAdminId(Long.valueOf(SecurityContextHolder.getContext().getAuthentication().getName()));
        } catch (Exception ignored) {
        }
        l.setOccurredAt(Instant.now());
        l.setAction(action);
        l.setModule(module);
        l.setRecordId(recordId);
        l.setPreviousValue(before);
        l.setNewValue(after);
        l.setIpAddress(request.getRemoteAddr());
        l.setBrowser(request.getHeader("User-Agent"));
        logs.save(l);
    }
}

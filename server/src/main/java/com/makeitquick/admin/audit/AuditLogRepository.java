package com.makeitquick.admin.audit; import org.springframework.data.jpa.repository.JpaRepository; public interface AuditLogRepository extends JpaRepository<AuditLog,Long> {}

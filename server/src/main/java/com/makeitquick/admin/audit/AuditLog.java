package com.makeitquick.admin.audit;
import jakarta.persistence.*; import lombok.*; import java.time.Instant;
@Entity @Table(name="audit_logs") @Getter @Setter @NoArgsConstructor
public class AuditLog { @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id; @Column(name="admin_id") private Long adminId; @Column(name="occurred_at") private Instant occurredAt; @Column(name="ip_address") private String ipAddress; private String browser; private String action; private String module; @Column(name="record_id") private String recordId;     @Column(name="previous_value",columnDefinition="json") private String previousValue; @Column(name="new_value",columnDefinition="json") private String newValue; }

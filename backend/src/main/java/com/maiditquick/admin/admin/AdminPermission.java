package com.maiditquick.admin.admin;

import jakarta.persistence.*;
import lombok.*;
@Entity @Table(name = "admin_permissions") @Getter @Setter @NoArgsConstructor
public class AdminPermission { @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id; @Column(nullable=false,unique=true) private String code; private String description; }

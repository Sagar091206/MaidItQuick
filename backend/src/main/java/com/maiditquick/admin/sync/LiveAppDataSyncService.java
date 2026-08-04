package com.maiditquick.admin.sync;

import com.maiditquick.admin.customers.Customer;
import com.maiditquick.admin.customers.CustomerRepository;
import com.maiditquick.admin.partners.Partner;
import com.maiditquick.admin.partners.PartnerRepository;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Instant;
import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Mirrors the real customer/worker app accounts into the admin read models. */
@Service
public class LiveAppDataSyncService {
  private final JdbcTemplate jdbc;
  private final CustomerRepository customers;
  private final PartnerRepository partners;
  private final Path mobileKycDirectory = Paths.get("..", "server", "uploads", "kyc").toAbsolutePath().normalize();
  private final Path adminPartnerDirectory = Paths.get("uploads", "partners").toAbsolutePath().normalize();

  public LiveAppDataSyncService(JdbcTemplate jdbc, CustomerRepository customers, PartnerRepository partners) {
    this.jdbc = jdbc;
    this.customers = customers;
    this.partners = partners;
  }

  @Transactional
  public void sync() {
    syncCustomers();
    syncPartners();
  }

  @Transactional
  public void approveWorker(long userId) {
    jdbc.update("UPDATE makeitquick.worker_profiles SET kyc_status='APPROVED', pan_status='APPROVED', selfie_status='APPROVED', address_status='APPROVED', background_check_status='APPROVED', payout_details_verified=1 WHERE user_id=?", userId);
  }

  @Transactional
  public void rejectWorker(long userId) {
    jdbc.update("UPDATE makeitquick.worker_profiles SET kyc_status=IF(kyc_status='PENDING','REJECTED',kyc_status), pan_status=IF(pan_status='PENDING','REJECTED',pan_status), selfie_status=IF(selfie_status='PENDING','REJECTED',selfie_status), address_status=IF(address_status='PENDING','REJECTED',address_status), background_check_status=IF(background_check_status='PENDING','REJECTED',background_check_status), payout_details_verified=0 WHERE user_id=?", userId);
  }

  private void syncCustomers() {
    for (Map<String, Object> row : jdbc.queryForList("SELECT id,name,email,phone,enabled,created_at FROM makeitquick.users WHERE role='CUSTOMER'")) {
      long id = number(row, "id");
      Customer customer = customers.findBySourceUserId(id).orElseGet(Customer::new);
      customer.setSourceUserId(id);
      customer.setName(text(row, "name", "Customer"));
      String email = text(row, "email", "");
      customer.setEmail(email.isBlank() ? "customer-" + id + "@maiditquick.local" : email);
      customer.setPhone(text(row, "phone", ""));
      customer.setStatus(bool(row, "enabled") ? "ACTIVE" : "SUSPENDED");
      if (customer.getCreatedAt() == null) customer.setCreatedAt(instant(row.get("created_at")));
      customer.setUpdatedAt(Instant.now());
      customers.save(customer);
    }
  }

  private void syncPartners() {
    String sql = "SELECT u.id,u.name,u.email,u.phone,u.enabled,u.created_at,"
        + "p.kyc_status,p.current_address,p.last_latitude,p.last_longitude,"
        + "p.identity_document_ref,p.address_document_ref,p.pan_document_ref,p.pan_number,p.pan_name,"
        + "p.payout_method,p.payout_account_holder_name,p.bank_account_last4,p.bank_ifsc,p.upi_id "
        + "FROM makeitquick.users u LEFT JOIN makeitquick.worker_profiles p ON p.user_id=u.id WHERE u.role='WORKER'";
    for (Map<String, Object> row : jdbc.queryForList(sql)) {
      long id = number(row, "id");
      Partner partner = partners.findBySourceUserId(id).orElseGet(Partner::new);
      partner.setSourceUserId(id);
      partner.setName(text(row, "name", "Partner"));
      String email = text(row, "email", "");
      partner.setEmail(email.isBlank() ? "worker-" + id + "@maiditquick.local" : email);
      String phone = text(row, "phone", "");
      partner.setPhone(phone.isBlank() || phone.length() > 40 ? "WORKER-" + id : phone);
      partner.setAddress(text(row, "current_address", ""));
      partner.setKycStatus(text(row, "kyc_status", "NOT_SUBMITTED"));
      partner.setIdentityDocPath(copyKycDocument(id, text(row, "identity_document_ref", ""), "identity"));
      partner.setAddressDocPath(copyKycDocument(id, text(row, "address_document_ref", ""), "address"));
      partner.setPanDocPath(copyKycDocument(id, text(row, "pan_document_ref", ""), "pan"));
      partner.setPanNumber(maskPan(text(row, "pan_number", "")));
      partner.setPanName(text(row, "pan_name", ""));
      partner.setBankAccountHolder(text(row, "payout_account_holder_name", ""));
      partner.setBankAccountNumber(maskAccount(text(row, "bank_account_last4", "")));
      partner.setBankIfsc(text(row, "bank_ifsc", ""));
      partner.setUpiId(text(row, "upi_id", ""));
      partner.setAccountStatus(bool(row, "enabled") ? "ACTIVE" : "SUSPENDED");
      partner.setLatitude(decimal(row.get("last_latitude")));
      partner.setLongitude(decimal(row.get("last_longitude")));
      if (partner.getCreatedAt() == null) partner.setCreatedAt(instant(row.get("created_at")));
      partner.setUpdatedAt(Instant.now());
      partners.save(partner);
    }
  }

  private static long number(Map<String,Object> row, String key) { return ((Number) row.get(key)).longValue(); }
  private static boolean bool(Map<String,Object> row, String key) { Object value=row.get(key); return value instanceof Boolean b ? b : value instanceof Number n && n.intValue()!=0; }
  private static String text(Map<String,Object> row, String key, String fallback) { Object value=row.get(key); return value == null ? fallback : value.toString(); }
  private static Double decimal(Object value) { return value instanceof Number n ? n.doubleValue() : null; }
  private static Instant instant(Object value) { return value instanceof java.sql.Timestamp timestamp ? timestamp.toInstant() : value instanceof Instant instant ? instant : Instant.now(); }
  private String copyKycDocument(long userId, String reference, String kind) {
    if (reference == null || reference.isBlank()) return null;
    String safeName = Paths.get(reference).getFileName().toString();
    Path source = mobileKycDirectory.resolve(safeName).normalize();
    if (!source.startsWith(mobileKycDirectory) || !Files.isRegularFile(source)) return null;
    String extension = safeName.contains(".") ? safeName.substring(safeName.lastIndexOf('.')) : ".bin";
    Path target = adminPartnerDirectory.resolve("worker-" + userId + "-" + kind + extension).normalize();
    try {
      Files.createDirectories(adminPartnerDirectory);
      Files.copy(source, target, java.nio.file.StandardCopyOption.REPLACE_EXISTING);
      return "/uploads/partners/" + target.getFileName();
    } catch (IOException ignored) {
      return null;
    }
  }
  private static String maskPan(String value) { return value == null || value.length() < 4 ? "" : "*****" + value.substring(value.length() - 4); }
  private static String maskAccount(String last4) { return last4 == null || last4.isBlank() ? "" : "**** " + last4; }
}
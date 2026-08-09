package com.makeitquick.admin.partners;

import com.makeitquick.worker.WorkerProfile;
import com.makeitquick.worker.WorkerProfileRepository;
import java.time.Instant;
import org.springframework.stereotype.Service;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.transaction.annotation.Transactional;

/** Keeps the admin KYC queue aligned with real worker onboarding submissions. */
@Service
public class LiveWorkerKycSyncService {
  private final WorkerProfileRepository workerProfiles;
  private final PartnerRepository partners;

  public LiveWorkerKycSyncService(WorkerProfileRepository workerProfiles, PartnerRepository partners) {
    this.workerProfiles = workerProfiles;
    this.partners = partners;
  }

  /** Refreshes the admin KYC mirror even when no administrator has a page open. */
  @Scheduled(fixedDelayString = "${app.kyc-sync-ms:60000}")
  public void scheduledSync() {
    sync();
  }
  @Transactional
  public void sync() {
    for (WorkerProfile profile : workerProfiles.findAll()) {
      long userId = profile.getUser().getId();
      Partner partner = partners.findBySourceUserId(userId).orElseGet(Partner::new);
      partner.setSourceUserId(userId);
      partner.setName(profile.getUser().getName());
      partner.setEmail(profile.getUser().getEmail());
      String phone = profile.getUser().getPhone();
      partner.setPhone(phone == null || phone.isBlank() || phone.length() > 40 ? "WORKER-" + userId : phone);
      partner.setAddress(profile.getCurrentAddress());
      partner.setKycStatus(profile.getKycStatus().name());
      partner.setAccountStatus(profile.getUser().isEnabled() ? "ACTIVE" : "SUSPENDED");
      partner.setIdentityDocPath(path(profile.getIdentityDocumentRef()));
      partner.setAddressDocPath(path(profile.getAddressDocumentRef()));
      partner.setPanDocPath(path(profile.getPanDocumentRef()));
      partner.setPanNumber(maskPan(profile.getPanNumber()));
      partner.setPanName(profile.getPanName());
      partner.setBankAccountHolder(profile.getPayoutAccountHolderName());
      partner.setBankAccountNumber(maskAccount(profile.getBankAccountLast4()));
      partner.setBankIfsc(profile.getBankIfsc());
      partner.setUpiId(profile.getUpiId());
      partner.setPayoutStatus(payoutStatus(profile));
      partner.setLatitude(profile.getLastLatitude());
      partner.setLongitude(profile.getLastLongitude());
      if (partner.getCreatedAt() == null) partner.setCreatedAt(profile.getUser().getCreatedAt());
      partner.setUpdatedAt(Instant.now());
      partners.save(partner);
    }
  }

  @Transactional
  public void approve(Partner partner) {
    if (partner.getSourceUserId() == null) return;
    workerProfiles.findByUser_Id(partner.getSourceUserId()).ifPresent(WorkerProfile::approve);
  }

  @Transactional
  public void approvePayout(Partner partner) {
    if (partner.getSourceUserId() == null) return;
    workerProfiles.findByUser_Id(partner.getSourceUserId()).ifPresent(WorkerProfile::approvePayoutDetails);
  }

  @Transactional
  public void reject(Partner partner) {
    if (partner.getSourceUserId() == null) return;
    workerProfiles.findByUser_Id(partner.getSourceUserId()).ifPresent(WorkerProfile::reject);
  }

  private static String payoutStatus(WorkerProfile profile) {
    if (!profile.hasPayoutDetails()) return "NOT_SUBMITTED";
    return profile.isPayoutDetailsVerified() ? "APPROVED" : "PENDING";
  }

  private static String path(String reference) {
    return reference == null || reference.isBlank() ? null : "/uploads/kyc/" + reference;
  }
  private static String maskPan(String pan) { return pan == null || pan.length() < 4 ? null : "*****" + pan.substring(pan.length() - 4); }
  private static String maskAccount(String last4) { return last4 == null || last4.isBlank() ? null : "**** " + last4; }
}
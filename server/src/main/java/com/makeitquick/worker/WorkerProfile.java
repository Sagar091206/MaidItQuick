package com.makeitquick.worker;

import com.makeitquick.operations.AvailabilityStatus;
import com.makeitquick.security.UserAccount;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.DayOfWeek;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.Locale;

@Entity
@Table(name = "worker_profiles")
public class WorkerProfile {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(optional = false)
    private UserAccount user;

    @Enumerated(EnumType.STRING)
    private VerificationStatus kycStatus = VerificationStatus.NOT_SUBMITTED;
    @Enumerated(EnumType.STRING)
    private VerificationStatus panStatus = VerificationStatus.NOT_SUBMITTED;
    @Enumerated(EnumType.STRING)
    private VerificationStatus selfieStatus = VerificationStatus.NOT_SUBMITTED;
    @Enumerated(EnumType.STRING)
    private VerificationStatus addressStatus = VerificationStatus.NOT_SUBMITTED;
    @Enumerated(EnumType.STRING)
    private VerificationStatus backgroundCheckStatus = VerificationStatus.NOT_SUBMITTED;
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private AvailabilityStatus availability = AvailabilityStatus.OFFLINE;

    private boolean consentAccepted;
    private Instant consentAcceptedAt;
    private String identityDocumentRef;
    private String panNumber;
    private String panName;
    private String panDocumentRef;
    private String profilePhotoRef;
    private String currentAddress;
    private String permanentAddress;
    private String city;
    private String state;
    private String pinCode;
    private String addressDocumentRef;
    private String policeVerificationRef;
    private String payoutMethod;
    private String payoutAccountHolderName;
    private String bankAccountLast4;
    private String bankIfsc;
    private String upiId;
    private boolean payoutDetailsVerified;
    private String serviceCategories;
    private String workLocations;
    private String experienceSummary;
    private String availabilitySummary;
    private String workingDays;
    private String workingStartTime;
    private String workingEndTime;
    private boolean partnerCodeAccepted;
    private Instant serviceReadinessSubmittedAt;
    private Double lastLatitude;
    private Double lastLongitude;
    private Instant locationUpdatedAt;

    protected WorkerProfile() {}

    public WorkerProfile(UserAccount user) {
        this.user = user;
    }

    public Long getId() { return id; }
    public UserAccount getUser() { return user; }
    public VerificationStatus getKycStatus() { return orDefault(kycStatus); }
    public VerificationStatus getPanStatus() { return orDefault(panStatus); }
    public VerificationStatus getSelfieStatus() { return orDefault(selfieStatus); }
    public VerificationStatus getAddressStatus() { return orDefault(addressStatus); }
    public VerificationStatus getBackgroundCheckStatus() { return orDefault(backgroundCheckStatus); }
    public AvailabilityStatus getAvailability() { return availability; }
    public boolean isConsentAccepted() { return consentAccepted; }
    public Instant getConsentAcceptedAt() { return consentAcceptedAt; }
    public String getPanNumber() { return panNumber; }
    public String getPanName() { return panName; }
    public String getCurrentAddress() { return currentAddress; }
    public String getPermanentAddress() { return permanentAddress; }
    public String getCity() { return city; }
    public String getState() { return state; }
    public String getPinCode() { return pinCode; }
    public boolean hasAddressProof() { return addressDocumentRef != null && !addressDocumentRef.isBlank(); }
    public String getIdentityDocumentRef() { return identityDocumentRef; }
    public String getPanDocumentRef() { return panDocumentRef; }
    public String getAddressDocumentRef() { return addressDocumentRef; }
    public String getPayoutMethod() { return payoutMethod; }
    public String getPayoutAccountHolderName() { return payoutAccountHolderName; }
    public String getBankAccountLast4() { return bankAccountLast4; }
    public String getBankIfsc() { return bankIfsc; }
    public String getUpiId() { return upiId; }
    public boolean isPayoutDetailsVerified() { return payoutDetailsVerified; }
    public String getServiceCategories() { return serviceCategories; }
    public String getWorkLocations() { return workLocations; }
    public String getExperienceSummary() { return experienceSummary; }
    public String getAvailabilitySummary() { return availabilitySummary; }
    public String getWorkingDays() { return workingDays; }
    public String getWorkingStartTime() { return workingStartTime; }
    public String getWorkingEndTime() { return workingEndTime; }
    public boolean isPartnerCodeAccepted() { return partnerCodeAccepted; }
    public Instant getServiceReadinessSubmittedAt() { return serviceReadinessSubmittedAt; }
    public Double getLastLatitude() { return lastLatitude; }
    public Double getLastLongitude() { return lastLongitude; }
    public Instant getLocationUpdatedAt() { return locationUpdatedAt; }

    public void acceptConsent() {
        consentAccepted = true;
        consentAcceptedAt = Instant.now();
    }

    public void submitKyc(String ref) {
        identityDocumentRef = ref;
        kycStatus = VerificationStatus.PENDING;
    }

    public void submitPan(String number, String name, String ref) {
        panNumber = number;
        panName = name;
        panDocumentRef = ref;
        panStatus = VerificationStatus.PENDING;
    }

    public void submitSelfie(String ref) {
        profilePhotoRef = ref;
        selfieStatus = VerificationStatus.PENDING;
    }

    public void submitAddress(String current, String permanent, String cityValue, String stateValue, String pin, String ref) {
        currentAddress = current;
        permanentAddress = permanent;
        city = cityValue;
        state = stateValue;
        pinCode = pin;
        if (ref != null && !ref.isBlank()) addressDocumentRef = ref;
        updateAddressStatus();
    }

    public void submitAddressProof(String ref) {
        addressDocumentRef = ref;
        updateAddressStatus();
    }

    public void submitPoliceVerification(String ref) {
        policeVerificationRef = ref;
        backgroundCheckStatus = VerificationStatus.PENDING;
    }

    public void setPayout(String method, String accountHolderName, String last4, String ifsc, String upi) {
        payoutMethod = method;
        payoutAccountHolderName = accountHolderName;
        bankAccountLast4 = last4;
        bankIfsc = ifsc;
        upiId = upi;
        payoutDetailsVerified = false;
    }

    public void submitServiceReadiness(
            String services,
            String locations,
            String experience,
            String availableWhen,
            boolean acceptedCode) {
        serviceCategories = services;
        workLocations = locations;
        experienceSummary = experience;
        availabilitySummary = availableWhen;
        partnerCodeAccepted = acceptedCode;
        serviceReadinessSubmittedAt = Instant.now();
    }

    public void approve() {
        kycStatus = VerificationStatus.APPROVED;
        panStatus = VerificationStatus.APPROVED;
        selfieStatus = VerificationStatus.APPROVED;
        addressStatus = VerificationStatus.APPROVED;
        backgroundCheckStatus = VerificationStatus.APPROVED;
        payoutDetailsVerified = true;
        partnerCodeAccepted = true;
    }

    public void reject() {
        if (getKycStatus() == VerificationStatus.PENDING) kycStatus = VerificationStatus.REJECTED;
        if (getPanStatus() == VerificationStatus.PENDING) panStatus = VerificationStatus.REJECTED;
        if (getSelfieStatus() == VerificationStatus.PENDING) selfieStatus = VerificationStatus.REJECTED;
        if (getAddressStatus() == VerificationStatus.PENDING) addressStatus = VerificationStatus.REJECTED;
        if (getBackgroundCheckStatus() == VerificationStatus.PENDING) backgroundCheckStatus = VerificationStatus.REJECTED;
        payoutDetailsVerified = false;
    }

    public boolean hasRejectedChecks() {
        return getKycStatus() == VerificationStatus.REJECTED
                || getPanStatus() == VerificationStatus.REJECTED
                || getSelfieStatus() == VerificationStatus.REJECTED
                || getAddressStatus() == VerificationStatus.REJECTED
                || getBackgroundCheckStatus() == VerificationStatus.REJECTED;
    }

    public boolean hasSubmittedApprovalPack() {
        return consentAccepted
                && getKycStatus() == VerificationStatus.PENDING
                && getPanStatus() == VerificationStatus.PENDING
                && getSelfieStatus() == VerificationStatus.PENDING
                && getAddressStatus() == VerificationStatus.PENDING
                && getBackgroundCheckStatus() == VerificationStatus.PENDING
                && hasPayoutDetails()
                && partnerCodeAccepted;
    }

    public boolean isReadyForJobs() {
        return consentAccepted
                && getKycStatus() == VerificationStatus.APPROVED
                && getPanStatus() == VerificationStatus.APPROVED
                && getSelfieStatus() == VerificationStatus.APPROVED
                && getAddressStatus() == VerificationStatus.APPROVED
                && getBackgroundCheckStatus() == VerificationStatus.APPROVED
                && payoutDetailsVerified
                && partnerCodeAccepted;
    }

    public void approvePayoutDetails() {
        if (!hasPayoutDetails()) throw new IllegalStateException("Payout details have not been submitted");
        payoutDetailsVerified = true;
    }

    public boolean hasPayoutDetails() {
        return payoutMethod != null && !payoutMethod.isBlank() && payoutAccountHolderName != null && !payoutAccountHolderName.isBlank();
    }

    public boolean hasAddressDetails() {
        return currentAddress != null && !currentAddress.isBlank()
                && permanentAddress != null && !permanentAddress.isBlank()
                && city != null && !city.isBlank()
                && state != null && !state.isBlank()
                && pinCode != null && !pinCode.isBlank();
    }

    public void setWorkLocations(String locations) {
        workLocations = locations;
    }

    public void setWorkingHours(String days, String startTime, String endTime) {
        workingDays = days;
        workingStartTime = startTime;
        workingEndTime = endTime;
    }

    public boolean isWorkingNow() {
        if (workingDays == null || workingDays.isBlank() || workingStartTime == null || workingEndTime == null) return true;
        try {
            var now = java.time.ZonedDateTime.now(ZoneId.of("Asia/Kolkata"));
            String day = now.getDayOfWeek().name().toLowerCase(Locale.ROOT);
            boolean scheduledToday = java.util.Arrays.stream(workingDays.toLowerCase(Locale.ROOT).split("[,/;]"))
                    .map(String::trim).anyMatch(value -> value.equals(day) || value.startsWith(day.substring(0, 3)));
            if (!scheduledToday) return false;
            LocalTime start = LocalTime.parse(workingStartTime);
            LocalTime end = LocalTime.parse(workingEndTime);
            LocalTime current = now.toLocalTime();
            return end.isAfter(start)
                    ? !current.isBefore(start) && !current.isAfter(end)
                    : !current.isBefore(start) || !current.isAfter(end);
        } catch (RuntimeException ignored) {
            return false;
        }
    }

    public void setAvailability(AvailabilityStatus value) {
        availability = value;
    }


    public void updateLocation(double latitude, double longitude) {
        lastLatitude = latitude;
        lastLongitude = longitude;
        locationUpdatedAt = Instant.now();
    }

    private VerificationStatus orDefault(VerificationStatus status) {
        return status == null ? VerificationStatus.NOT_SUBMITTED : status;
    }

    private void updateAddressStatus() {
        addressStatus = hasAddressDetails() && hasAddressProof()
                ? VerificationStatus.PENDING
                : VerificationStatus.NOT_SUBMITTED;
    }
}

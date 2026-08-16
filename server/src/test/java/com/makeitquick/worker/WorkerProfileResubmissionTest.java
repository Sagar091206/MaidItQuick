package com.makeitquick.worker;

import static org.assertj.core.api.Assertions.assertThat;

import com.makeitquick.security.Role;
import com.makeitquick.security.UserAccount;
import org.junit.jupiter.api.Test;

class WorkerProfileResubmissionTest {
    @Test
    void rejectedChecksReturnToPendingWhenReplacementDocumentsAreSubmitted() {
        UserAccount worker = new UserAccount(
                "Resubmission Partner", "", "password", "+919876500999", Role.WORKER);
        WorkerProfile profile = new WorkerProfile(worker);
        profile.acceptConsent();
        profile.submitKyc("identity-v1");
        profile.submitPan("ABCDE1234F", worker.getName(), "pan-v1");
        profile.submitSelfie("selfie-v1");
        profile.submitAddress("Current", "Permanent", "Kolkata", "West Bengal", "700001", "address-v1");
        profile.submitPoliceVerification("police-v1");
        profile.setPayout("BANK", worker.getName(), "1234", "HDFC0000001", null);
        profile.submitServiceReadiness("Cleaning", "700001", "Two years", "Weekdays", true);

        assertThat(profile.hasSubmittedApprovalPack()).isTrue();
        profile.reject();

        assertThat(profile.hasRejectedChecks()).isTrue();
        assertThat(profile.hasSubmittedApprovalPack()).isFalse();

        profile.submitKyc("identity-v2");
        profile.submitPan("ABCDE1234F", worker.getName(), "pan-v2");
        profile.submitSelfie("selfie-v2");
        profile.submitAddressProof("address-v2");
        profile.submitPoliceVerification("police-v2");

        assertThat(profile.hasRejectedChecks()).isFalse();
        assertThat(profile.hasSubmittedApprovalPack()).isTrue();
    }
}

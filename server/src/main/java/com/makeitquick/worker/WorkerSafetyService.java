package com.makeitquick.worker;

import com.makeitquick.operations.AvailabilityStatus;
import com.makeitquick.security.UserAccount;
import org.springframework.stereotype.Service;

@Service
public class WorkerSafetyService {
    private final WorkerProfileRepository profiles;

    WorkerSafetyService(WorkerProfileRepository profiles) {
        this.profiles = profiles;
    }

    public boolean eligibleForDispatch(UserAccount worker) {
        return profiles.findByUser(worker)
                .map(profile -> profile.getKycStatus() == VerificationStatus.APPROVED
                        && profile.getBackgroundCheckStatus() == VerificationStatus.APPROVED
                        && profile.getAvailability() == AvailabilityStatus.AVAILABLE)
                .orElse(false);
    }

    public long eligibleAvailableWorkerCount() {
        return profiles.findAll().stream().filter(profile ->
                profile.getKycStatus() == VerificationStatus.APPROVED
                        && profile.getBackgroundCheckStatus() == VerificationStatus.APPROVED
                        && profile.getAvailability() == AvailabilityStatus.AVAILABLE).count();
    }
}

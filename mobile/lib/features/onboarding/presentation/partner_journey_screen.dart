import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../../core/document_picker.dart';
import '../../../core/text_to_speech.dart';
import '../../../shared/widgets/onboarding_bottom_bar.dart';
import '../../../shared/widgets/onboarding_step_card.dart';
import '../../auth/data/auth_repository.dart';
import '../../dashboard/data/partner_repository.dart';
import '../../dashboard/presentation/partner_dashboard_screen.dart';

class PartnerJourneyScreen extends StatefulWidget {
  const PartnerJourneyScreen(
      {super.key,
      required this.api,
      required this.session,
      required this.onLogout});

  final ApiClient api;
  final Session session;
  final VoidCallback onLogout;

  @override
  State<PartnerJourneyScreen> createState() => _PartnerJourneyScreenState();
}

class _PartnerJourneyScreenState extends State<PartnerJourneyScreen> {
  final _panNumber = TextEditingController();
  final _panName = TextEditingController();
  final _currentAddress = TextEditingController();
  final _permanentAddress = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pinCode = TextEditingController();
  final _accountHolderName = TextEditingController();
  final _accountNumber = TextEditingController();
  final _ifsc = TextEditingController();
  final _upiId = TextEditingController();
  final _onboardingScrollController = ScrollController();
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _applicationStatusData;
  bool _statusLoading = false;
  String? _statusError;
  KycDocument? _identityDocument;
  KycDocument? _panDocument;
  KycDocument? _profilePhoto;
  KycDocument? _addressDocument;
  String _payoutMethod = 'BANK';
  bool _loading = true;
  String? _busyAction;
  int _selectedOnboardingTab = 0;

  late final PartnerRepository _partnerRepository =
      PartnerRepository(widget.api);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _panNumber.dispose();
    _panName.dispose();
    _currentAddress.dispose();
    _permanentAddress.dispose();
    _city.dispose();
    _state.dispose();
    _pinCode.dispose();
    _accountHolderName.dispose();
    _accountNumber.dispose();
    _ifsc.dispose();
    _upiId.dispose();
    _onboardingScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _partnerRepository.fetchProfile(widget.session.token);
      if (mounted) setState(() => _profile = data);
      await _loadApplicationStatus(showMessage: false);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadApplicationStatus({bool showMessage = true}) async {
    if (mounted) {
      setState(() {
        _statusLoading = true;
        _statusError = null;
      });
    }

    try {
      final data = await _partnerRepository.fetchProfile(widget.session.token);

      if (!mounted) return;
      setState(() => _applicationStatusData = data);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _statusError = error.message);
      if (showMessage) _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      const message = 'Application status is currently unavailable.';
      setState(() => _statusError = message);
      if (showMessage) _showMessage(message);
    } finally {
      if (mounted) setState(() => _statusLoading = false);
    }
  }

  Future<void> _pickDocument(ValueChanged<KycDocument> onPicked) async {
    try {
      final document = await KycDocumentPicker.pick();
      if (document == null || !mounted) return;
      setState(() => onPicked(document));
    } on KycDocumentPickerException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _pickPhoto(ValueChanged<KycDocument> onPicked) async {
    try {
      final document = await KycDocumentPicker.pickPhoto();
      if (document == null || !mounted) return;
      setState(() => onPicked(document));
    } on KycDocumentPickerException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _acceptConsent() async {
    await _run('consent', () async {
      final profile =
          await _partnerRepository.acceptConsent(widget.session.token);
      if (mounted) {
        setState(() => _profile = profile);
        _showMessage('Consent saved.');
      }
    });
  }

  Future<void> _submitIdentity() async {
    final document = _identityDocument;
    if (document == null) {
      _showMessage('Choose a PDF, JPG or PNG identity document first.');
      return;
    }
    await _uploadDocument(
      action: 'identity',
      document: document,
      upload: () => _partnerRepository.submitIdentityDocument(
        token: widget.session.token,
        document: document,
      ),
      success: 'Identity document submitted for review.',
    );
  }

  Future<void> _submitPan() async {
    final document = _panDocument;
    final pan = _panNumber.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{5}\d{4}[A-Z]$').hasMatch(pan) ||
        _panName.text.trim().isEmpty) {
      _showMessage('Enter a valid PAN number and PAN name.');
      return;
    }
    if (document == null) {
      _showMessage('Choose a PAN document first.');
      return;
    }
    await _uploadDocument(
      action: 'pan',
      document: document,
      upload: () => _partnerRepository.submitPan(
        token: widget.session.token,
        panNumber: pan,
        panName: _panName.text.trim(),
        document: document,
      ),
      success: 'PAN submitted for review.',
    );
  }

  Future<void> _submitProfilePhoto() async {
    final document = _profilePhoto;
    if (document == null) {
      _showMessage('Choose a JPG or PNG profile photo first.');
      return;
    }
    await _uploadDocument(
      action: 'photo',
      document: document,
      upload: () => _partnerRepository.submitProfilePhoto(
        token: widget.session.token,
        document: document,
      ),
      success: 'Profile photo submitted for review.',
    );
  }

  Future<void> _saveAddress() async {
    final document = _addressDocument;
    if (_currentAddress.text.trim().isEmpty ||
        _permanentAddress.text.trim().isEmpty ||
        _city.text.trim().isEmpty ||
        _state.text.trim().isEmpty ||
        !RegExp(r'^\d{6}$').hasMatch(_pinCode.text.trim())) {
      _showMessage(
          'Enter current address, permanent address, city, state and 6 digit PIN.');
      return;
    }
    if (document == null) {
      _showMessage('Choose a PDF, JPG or PNG address proof first.');
      return;
    }
    if (document.bytes.lengthInBytes > 5 * 1024 * 1024) {
      _showMessage('The document must be smaller than 5 MB.');
      return;
    }
    await _run('address', () async {
      await _partnerRepository.saveAddress(
        token: widget.session.token,
        currentAddress: _currentAddress.text.trim(),
        permanentAddress: _permanentAddress.text.trim(),
        city: _city.text.trim(),
        state: _state.text.trim(),
        pinCode: _pinCode.text.trim(),
      );
      final profile = await _partnerRepository.submitAddressProof(
        token: widget.session.token,
        document: document,
      );
      if (mounted) {
        setState(() => _profile = profile);
        _showMessage('Address details and proof submitted for review.');
      }
    });
  }

  Future<void> _savePayout() async {
    if (_accountHolderName.text.trim().isEmpty) {
      _showMessage('Enter the payout account holder name.');
      return;
    }
    final accountNumber =
        _accountNumber.text.replaceAll(RegExp(r'\s+'), '').trim();

    final ifsc = _ifsc.text.trim().toUpperCase();
    if (_payoutMethod == 'BANK' &&
        (!RegExp(r'^\d{9,18}$').hasMatch(accountNumber) ||
            !RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifsc))) {
      _showMessage(
        'Enter a valid 9 to 18 digit account number and 11-character IFSC code.',
      );
      return;
    }
    if (_payoutMethod == 'UPI' && _upiId.text.trim().isEmpty) {
      _showMessage('Enter the UPI ID.');
      return;
    }
    await _run('payout', () async {
      final profile = await _partnerRepository.savePayout(
        token: widget.session.token,
        method: _payoutMethod,
        accountHolderName: _accountHolderName.text.trim(),
        accountNumber: accountNumber,
        ifsc: ifsc,
        upiId: _upiId.text.trim(),
      );
      if (mounted) {
        setState(() => _profile = profile);
        _showMessage('Payout details saved for verification.');
      }
    });
  }

  Future<void> _setAvailable() async {
    await _run('available', () async {
      final profile = await _partnerRepository.setAvailability(
          widget.session.token, 'AVAILABLE');
      if (mounted) {
        setState(() => _profile = profile);
        _showMessage('You are now available for jobs.');
      }
    });
  }

  Future<void> _uploadDocument({
    required String action,
    required KycDocument document,
    required Future<Map<String, dynamic>> Function() upload,
    required String success,
  }) async {
    if (document.bytes.lengthInBytes > 5 * 1024 * 1024) {
      _showMessage('The document must be smaller than 5 MB.');
      return;
    }
    await _run(action, () async {
      final profile = await upload();
      if (mounted) {
        setState(() => _profile = profile);
        _showMessage(success);
      }
    });
  }

  Future<void> _run(String action, Future<void> Function() work) async {
    setState(() => _busyAction = action);
    try {
      await work();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  void _openPartnerDashboard() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PartnerDashboardScreen(
          api: widget.api,
          session: widget.session,
          onLogout: widget.onLogout,
          initialProfile: _profile,
          onManageVerification: (tabIndex) {
            Navigator.of(context).pop();
            setState(() => _selectedOnboardingTab = tabIndex);
          },
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final consentAccepted = profile?['consentAccepted'] == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner onboarding'),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !consentAccepted
              ? _PartnerConsentScreen(
                  partnerName: widget.session.name,
                  saving: _isBusy('consent'),
                  onAccept: _acceptConsent,
                )
              : DefaultTabController(
                  key: ValueKey(_selectedOnboardingTab),
                  length: 5,
                  initialIndex: _selectedOnboardingTab,
                  child: SafeArea(
                    child: _showOnboardingFooter
                        ? Column(
                            children: [
                              Expanded(
                                child: _buildOnboardingScrollArea(),
                              ),
                              OnboardingBottomBar(
                                child: _buildOnboardingFooter(),
                              ),
                            ],
                          )
                        : _buildOnboardingScrollArea(),
                  ),
                ),
    );
  }

  /// Whether the current tab pins its submit actions to the bottom bar.
  bool get _showOnboardingFooter =>
      _selectedOnboardingTab == 1 ||
      _selectedOnboardingTab == 2 ||
      _selectedOnboardingTab == 3;

  Widget _buildOnboardingScrollArea() {
    return Scrollbar(
      controller: _onboardingScrollController,
      thumbVisibility: true,
      child: ListView(
        controller: _onboardingScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        children: [
          Text(
            'Welcome, ${widget.session.name}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Complete identity, address and payout verification to start receiving jobs.',
            style: TextStyle(color: BrandColors.muted),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: BrandColors.muted.withValues(alpha: 0.35),
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              onTap: (index) => setState(() => _selectedOnboardingTab = index),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Identity'),
                Tab(text: 'Address'),
                Tab(text: 'Payout'),
                Tab(text: 'Status'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildSelectedOnboardingTab(),
        ],
      ),
    );
  }

  Widget _buildOnboardingFooter() {
    switch (_selectedOnboardingTab) {
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: _isBusy('identity') ? null : _submitIdentity,
              child: Text(_buttonLabel('identity', 'Submit identity')),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _isBusy('pan') ? null : _submitPan,
              child: Text(_buttonLabel('pan', 'Submit PAN')),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _isBusy('photo') ? null : _submitProfilePhoto,
              child: Text(_buttonLabel('photo', 'Submit photo')),
            ),
          ],
        );
      case 2:
        return FilledButton(
          onPressed: _isBusy('address') ? null : _saveAddress,
          child: Text(_buttonLabel('address', 'Submit address and proof')),
        );
      case 3:
        return FilledButton(
          onPressed: _isBusy('payout') ? null : _savePayout,
          child: Text(_buttonLabel('payout', 'Save payout details')),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSelectedOnboardingTab() {
    return switch (_selectedOnboardingTab) {
      1 => _buildIdentityTab(),
      2 => _buildAddressTab(),
      3 => _buildPayoutTab(),
      4 => _buildStatusTab(),
      _ => _buildOverviewTab(),
    };
  }

  Widget _buildOverviewTab() {
    final profile = _profile;
    final readyForJobs = profile?['readyForJobs'] == true;
    final statuses = [
      _status('identityStatus'),
      _status('panStatus'),
      _status('selfieStatus'),
      _status('addressStatus'),
    ];
    final approvedCount =
        statuses.where((status) => status == 'APPROVED').length;
    final progress = approvedCount / statuses.length;

    return ListView(
      primary: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 7,
                        backgroundColor:
                            BrandColors.muted.withValues(alpha: 0.22),
                      ),
                      Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Overall progress',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$approvedCount of ${statuses.length} checks approved',
                        style: const TextStyle(color: BrandColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        OnboardingStepCard(
          number: '1',
          title: 'Identity verification',
          status: _identityGroupStatus,
          initiallyExpanded: true,
          children: [
            _PartnerStatusCard(
              title: 'Identity document',
              status: _status('identityStatus'),
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 10),
            _PartnerStatusCard(
              title: 'PAN verification',
              status: _status('panStatus'),
              icon: Icons.assignment_ind_outlined,
            ),
            const SizedBox(height: 10),
            _PartnerStatusCard(
              title: 'Selfie / profile photo',
              status: _status('selfieStatus'),
              icon: Icons.account_circle_outlined,
            ),
          ],
        ),
        OnboardingStepCard(
          number: '2',
          title: 'Address verification',
          status: _status('addressStatus'),
          children: [
            _PartnerStatusCard(
              title: 'Address and proof',
              status: _status('addressStatus'),
              icon: Icons.location_on_outlined,
            ),
          ],
        ),
        OnboardingStepCard(
          number: '3',
          title: 'Payout details',
          status: _payoutStatus,
          children: [
            _PartnerStatusCard(
              title: 'Payout verification',
              status: _payoutStatus,
              icon: Icons.account_balance_outlined,
            ),
          ],
        ),
        OnboardingStepCard(
          number: '4',
          title: 'Start receiving jobs',
          status: readyForJobs ? 'READY' : 'LOCKED',
          children: [
            Text(
              readyForJobs
                  ? 'All required checks are approved. You can go available now.'
                  : 'This option unlocks after identity, address and payout approval.',
              style: const TextStyle(color: BrandColors.muted),
            ),
            const SizedBox(height: 12),
            _PartnerStatusCard(
              title: 'Job availability',
              status: profile?['availability']?.toString() ?? 'OFFLINE',
              icon: Icons.work_outline,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  !readyForJobs || _isBusy('available') ? null : _setAvailable,
              icon: const Icon(Icons.toggle_on_outlined),
              label: Text(_buttonLabel('available', 'Go available')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.dashboard_customize_outlined,
                      color: BrandColors.lime,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Open Partner Dashboard',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'You can open the dashboard even while verification is pending. Going online and receiving jobs remain locked until approval.',
                            style: TextStyle(color: BrandColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openPartnerDashboard,
                    icon: Icon(Icons.arrow_forward),
                    label: Text('Go to Dashboard'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _loading ? null : _loadProfile,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh status'),
        ),
      ],
    );
  }

  Widget _buildIdentityTab() {
    return ListView(
      primary: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        OnboardingStepCard(
          number: '1',
          title: 'Identity document',
          status: _status('identityStatus'),
          initiallyExpanded: true,
          children: [
            const Text(
              'Accepted: PAN, driving licence, voter ID, passport or masked Aadhaar as PDF, JPG or PNG.',
              style: TextStyle(color: BrandColors.muted),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  _pickDocument((document) => _identityDocument = document),
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(
                _identityDocument?.name ?? 'Choose identity document',
              ),
            ),
          ],
        ),
        OnboardingStepCard(
          number: '2',
          title: 'PAN verification',
          status: _status('panStatus'),
          children: [
            TextField(
              controller: _panNumber,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'PAN number'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _panName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name on PAN'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  _pickDocument((document) => _panDocument = document),
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(_panDocument?.name ?? 'Choose PAN document'),
            ),
          ],
        ),
        OnboardingStepCard(
          number: '3',
          title: 'Selfie / profile photo',
          status: _status('selfieStatus'),
          children: [
            const Text(
              'Upload a current JPG or PNG photo for safety review and profile matching.',
              style: TextStyle(color: BrandColors.muted),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  _pickPhoto((document) => _profilePhoto = document),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(_profilePhoto?.name ?? 'Choose photo'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddressTab() {
    return ListView(
      primary: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        OnboardingStepCard(
          number: '1',
          title: 'Address verification',
          status: _status('addressStatus'),
          initiallyExpanded: true,
          children: [
            const Text(
              'Add your address details and upload address proof as PDF, JPG or PNG.',
              style: TextStyle(color: BrandColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _currentAddress,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Current address'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _permanentAddress,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Permanent address'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _city,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'City'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _state,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'State'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinCode,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'PIN code',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  _pickDocument((document) => _addressDocument = document),
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(_addressDocument?.name ?? 'Choose address proof'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPayoutTab() {
    return ListView(
      primary: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        OnboardingStepCard(
          number: '1',
          title: 'Payout details',
          status: _payoutStatus,
          initiallyExpanded: true,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'BANK',
                  icon: Icon(Icons.account_balance_outlined),
                  label: Text('Bank'),
                ),
                ButtonSegment<String>(
                  value: 'UPI',
                  icon: Icon(Icons.qr_code_2_outlined),
                  label: Text('UPI'),
                ),
              ],
              selected: {_payoutMethod},
              onSelectionChanged: (value) =>
                  setState(() => _payoutMethod = value.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _accountHolderName,
              textCapitalization: TextCapitalization.words,
              decoration:
                  const InputDecoration(labelText: 'Account holder name'),
            ),
            const SizedBox(height: 12),
            if (_payoutMethod == 'BANK') ...[
              TextField(
                controller: _accountNumber,
                keyboardType: TextInputType.number,
                maxLength: 18,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Account number',
                  hintText: 'Enter full bank account number',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ifsc,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'IFSC code'),
              ),
            ] else
              TextField(
                controller: _upiId,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'UPI ID'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusTab() {
    if (_statusLoading && _applicationStatusData == null) {
      return const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final outcome = _applicationOutcome;
    final stageIndex = _currentStageIndex;
    final correctionReason = _safeCorrectionReason;
    final lastUpdated = _statusLastUpdated;

    return ListView(
      primary: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        const Text(
          'Application status',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Track your application from submission to Partner activation.',
          style: TextStyle(color: BrandColors.muted),
        ),
        const SizedBox(height: 16),
        _ApplicationStatusSummary(
          outcome: outcome,
          stageLabel: _stageLabel(stageIndex),
          stageNumber: stageIndex + 1,
          totalStages: _applicationStages.length,
          lastUpdated: lastUpdated,
        ),
        if (_statusError != null) ...[
          const SizedBox(height: 14),
          _ApplicationMessageCard(
            icon: Icons.cloud_off_outlined,
            title: 'Status unavailable',
            message: _statusError!,
            accent: Colors.orangeAccent,
          ),
        ],
        const SizedBox(height: 18),
        const Text(
          'Status timeline',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        _ApplicationTimeline(
          stages: _applicationStages,
          currentStage: stageIndex,
          outcome: outcome,
        ),
        const SizedBox(height: 18),
        if (outcome == 'CHANGES_REQUIRED')
          _ApplicationMessageCard(
            icon: Icons.edit_note_outlined,
            title: 'Changes required',
            message: correctionReason ??
                'One or more sections need correction before review can continue.',
            accent: Colors.orangeAccent,
          )
        else if (outcome == 'APPROVED')
          const _ApplicationMessageCard(
            icon: Icons.verified_outlined,
            title: 'Application approved',
            message:
                'Your Partner application has been approved. You can continue to the dashboard.',
            accent: BrandColors.lime,
          )
        else if (outcome == 'REJECTED')
          _ApplicationMessageCard(
            icon: Icons.cancel_outlined,
            title: 'Application rejected',
            message: correctionReason ??
                'Your application could not be approved. Contact support for assistance.',
            accent: Colors.redAccent,
          )
        else
          const _ApplicationMessageCard(
            icon: Icons.hourglass_top_outlined,
            title: 'Under review',
            message:
                'Your application is being reviewed. No action is required unless MaidItQuick requests changes.',
            accent: Colors.amber,
          ),
        const SizedBox(height: 14),
        if (outcome == 'CHANGES_REQUIRED')
          FilledButton.icon(
            onPressed: _goToCorrectionSection,
            icon: const Icon(Icons.build_outlined),
            label: const Text('Fix details'),
          )
        else if (outcome == 'APPROVED')
          FilledButton.icon(
            onPressed: _setAvailable,
            icon: const Icon(Icons.dashboard_outlined),
            label: const Text('Continue to dashboard'),
          ),
        if (outcome == 'CHANGES_REQUIRED' || outcome == 'REJECTED')
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.support_agent_outlined),
              label: const Text('Contact support'),
            ),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _statusLoading ? null : () => _loadApplicationStatus(),
          icon: const Icon(Icons.refresh),
          label: Text(_statusLoading ? 'Refreshing...' : 'Refresh status'),
        ),
      ],
    );
  }

  static const List<String> _applicationStages = [
    'Profile completed',
    'KYC submitted',
    'Documents under review',
    'Background verification',
    'Bank verification',
    'Final approval',
    'Partner activated',
  ];

  String get _applicationOutcome {
    final raw = (_applicationStatusData?['outcome'] ??
            _applicationStatusData?['status'] ??
            _applicationStatusData?['applicationStatus'] ??
            'UNDER_REVIEW')
        .toString()
        .toUpperCase()
        .replaceAll(' ', '_');

    if (raw.contains('CHANGE')) return 'CHANGES_REQUIRED';
    if (raw.contains('APPROV')) return 'APPROVED';
    if (raw.contains('REJECT')) return 'REJECTED';
    return 'UNDER_REVIEW';
  }

  int get _currentStageIndex {
    final data = _applicationStatusData;

    final numeric = data?['stageIndex'] ??
        data?['currentStageIndex'] ??
        data?['stageNumber'];
    if (numeric is num) {
      final value = numeric.toInt();
      if (data?['stageNumber'] != null) {
        return (value - 1).clamp(0, _applicationStages.length - 1);
      }
      return value.clamp(0, _applicationStages.length - 1);
    }

    final raw =
        (data?['currentStage'] ?? data?['stage'] ?? data?['stageLabel'] ?? '')
            .toString()
            .toLowerCase();

    for (var index = 0; index < _applicationStages.length; index++) {
      final label = _applicationStages[index].toLowerCase();
      if (raw == label || raw.contains(label) || label.contains(raw)) {
        return index;
      }
    }

    if (_applicationOutcome == 'APPROVED') {
      return _applicationStages.length - 1;
    }

    if (_status('identityStatus') == 'APPROVED' &&
        _status('panStatus') == 'APPROVED' &&
        _status('selfieStatus') == 'APPROVED') {
      return 2;
    }

    return 0;
  }

  String? get _safeCorrectionReason {
    final value = _applicationStatusData?['correctionReason'] ??
        _applicationStatusData?['partnerMessage'] ??
        _applicationStatusData?['rejectionReason'];

    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String get _statusLastUpdated {
    final value = _applicationStatusData?['lastUpdatedAt'] ??
        _applicationStatusData?['updatedAt'] ??
        _applicationStatusData?['statusUpdatedAt'];

    final text = value?.toString().trim();
    return text == null || text.isEmpty ? 'Not available' : text;
  }

  String _stageLabel(int index) =>
      _applicationStages[index.clamp(0, _applicationStages.length - 1)];

  void _goToCorrectionSection() {
    final section = (_applicationStatusData?['correctionSection'] ??
            _applicationStatusData?['requiredActionSection'] ??
            '')
        .toString()
        .toLowerCase();

    final controller = DefaultTabController.of(context);

    if (section.contains('address')) {
      controller.animateTo(2);
    } else if (section.contains('bank') ||
        section.contains('payout') ||
        section.contains('upi')) {
      controller.animateTo(3);
    } else {
      controller.animateTo(1);
    }
  }

  String get _identityGroupStatus {
    final statuses = [
      _status('identityStatus'),
      _status('panStatus'),
      _status('selfieStatus'),
    ];
    if (statuses.every((status) => status == 'APPROVED')) return 'APPROVED';
    if (statuses.any((status) => status == 'PENDING')) return 'PENDING';
    if (statuses.any((status) => status == 'REJECTED')) {
      return 'ACTION REQUIRED';
    }
    return 'NOT SUBMITTED';
  }

  String get _payoutStatus {
    final profile = _profile;
    return profile?['payoutStatus']?.toString() ??
        profile?['payoutVerificationStatus']?.toString() ??
        (profile?['payoutConfigured'] == true ? 'APPROVED' : 'NOT SUBMITTED');
  }

  String _status(String key) => _profile?[key]?.toString() ?? 'NOT_SUBMITTED';
  bool _isBusy(String action) => _busyAction == action;
  String _buttonLabel(String action, String label) =>
      _isBusy(action) ? 'Saving...' : label;
}

class _ApplicationStatusSummary extends StatelessWidget {
  const _ApplicationStatusSummary({
    required this.outcome,
    required this.stageLabel,
    required this.stageNumber,
    required this.totalStages,
    required this.lastUpdated,
  });

  final String outcome;
  final String stageLabel;
  final int stageNumber;
  final int totalStages;
  final String lastUpdated;

  @override
  Widget build(BuildContext context) {
    final label = outcome.replaceAll('_', ' ');
    final color = switch (outcome) {
      'APPROVED' => BrandColors.lime,
      'CHANGES_REQUIRED' => Colors.orangeAccent,
      'REJECTED' => Colors.redAccent,
      _ => Colors.amber,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fact_check_outlined, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '$stageNumber/$totalStages',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: stageNumber / totalStages,
              minHeight: 8,
              backgroundColor: BrandColors.muted.withValues(alpha: 0.22),
            ),
            const SizedBox(height: 12),
            Text(
              stageLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Last updated: $lastUpdated',
              style: const TextStyle(
                color: BrandColors.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationTimeline extends StatelessWidget {
  const _ApplicationTimeline({
    required this.stages,
    required this.currentStage,
    required this.outcome,
  });

  final List<String> stages;
  final int currentStage;
  final String outcome;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(stages.length, (index) {
        final complete = index < currentStage ||
            (outcome == 'APPROVED' && index <= currentStage);
        final current = index == currentStage;
        final isLast = index == stages.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 38,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: complete
                        ? BrandColors.lime
                        : current
                            ? BrandColors.lime.withValues(alpha: 0.22)
                            : BrandColors.muted.withValues(alpha: 0.18),
                    foregroundColor: complete
                        ? BrandColors.evergreen
                        : current
                            ? BrandColors.lime
                            : BrandColors.muted,
                    child: complete
                        ? const Icon(Icons.check, size: 18)
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 54,
                      color: complete
                          ? BrandColors.lime
                          : BrandColors.muted.withValues(alpha: 0.25),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: current
                        ? BrandColors.lime
                        : BrandColors.muted.withValues(alpha: 0.25),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        stages[index],
                        style: TextStyle(
                          fontWeight:
                              current ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (current)
                      const Text(
                        'CURRENT',
                        style: TextStyle(
                          color: BrandColors.lime,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _ApplicationMessageCard extends StatelessWidget {
  const _ApplicationMessageCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    message,
                    style: const TextStyle(
                      color: BrandColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerConsentScreen extends StatefulWidget {
  const _PartnerConsentScreen({
    required this.partnerName,
    required this.saving,
    required this.onAccept,
  });

  final String partnerName;
  final bool saving;
  final VoidCallback onAccept;

  @override
  State<_PartnerConsentScreen> createState() => _PartnerConsentScreenState();
}

class _PartnerConsentScreenState extends State<_PartnerConsentScreen> {
  final _scrollController = ScrollController();
  _ConsentLanguage _selectedLanguage = _consentLanguages.first;
  Timer? _speechResetTimer;
  bool _speaking = false;

  @override
  void dispose() {
    _speechResetTimer?.cancel();
    AppTextToSpeech.stop();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _listen() async {
    if (_speaking) {
      _speechResetTimer?.cancel();
      await AppTextToSpeech.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }

    setState(() => _speaking = true);
    try {
      await AppTextToSpeech.speak(
        text: _selectedLanguage.audioText(widget.partnerName),
        languageCode: _selectedLanguage.speechCode,
      );
    } on TextToSpeechException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      _speechResetTimer?.cancel();
      _speechResetTimer = Timer(_selectedLanguage.estimatedDuration, () {
        if (mounted) setState(() => _speaking = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Icon(
                      Icons.privacy_tip_outlined,
                      color: BrandColors.lime,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _selectedLanguage.title(widget.partnerName),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _selectedLanguage.intro,
                    style: TextStyle(color: BrandColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<_ConsentLanguage>(
                    initialValue: _selectedLanguage,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _selectedLanguage.languageLabel,
                      prefixIcon: const Icon(Icons.translate_outlined),
                    ),
                    items: _consentLanguages
                        .map(
                          (language) => DropdownMenuItem<_ConsentLanguage>(
                            value: language,
                            child: Text(language.name),
                          ),
                        )
                        .toList(),
                    onChanged: (language) {
                      if (language == null) return;
                      _speechResetTimer?.cancel();
                      AppTextToSpeech.stop();
                      setState(() {
                        _selectedLanguage = language;
                        _speaking = false;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _listen,
                    icon: Icon(
                      _speaking
                          ? Icons.stop_circle_outlined
                          : Icons.volume_up_outlined,
                    ),
                    label: Text(
                      _speaking
                          ? _selectedLanguage.stopAudioLabel
                          : _selectedLanguage.listenLabel,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _ConsentPoint(
                    icon: Icons.manage_accounts_outlined,
                    title: _selectedLanguage.profileTitle,
                    body: _selectedLanguage.profileBody,
                  ),
                  _ConsentPoint(
                    icon: Icons.badge_outlined,
                    title: _selectedLanguage.identityTitle,
                    body: _selectedLanguage.identityBody,
                  ),
                  _ConsentPoint(
                    icon: Icons.account_balance_outlined,
                    title: _selectedLanguage.payoutTitle,
                    body: _selectedLanguage.payoutBody,
                  ),
                  _ConsentPoint(
                    icon: Icons.admin_panel_settings_outlined,
                    title: _selectedLanguage.operationsTitle,
                    body: _selectedLanguage.operationsBody,
                  ),
                  _ConsentPoint(
                    icon: Icons.edit_note_outlined,
                    title: _selectedLanguage.correctionTitle,
                    body: _selectedLanguage.correctionBody,
                  ),
                ],
              ),
            ),
          ),
        ),
        OnboardingBottomBar(
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.saving ? null : widget.onAccept,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                widget.saving
                    ? _selectedLanguage.savingLabel
                    : _selectedLanguage.acceptLabel,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConsentLanguage {
  const _ConsentLanguage({
    required this.name,
    required this.speechCode,
    required this.languageLabel,
    required this.listenLabel,
    required this.stopAudioLabel,
    required this.savingLabel,
    required this.acceptLabel,
    required this.titlePrefix,
    required this.intro,
    required this.profileTitle,
    required this.profileBody,
    required this.identityTitle,
    required this.identityBody,
    required this.payoutTitle,
    required this.payoutBody,
    required this.operationsTitle,
    required this.operationsBody,
    required this.correctionTitle,
    required this.correctionBody,
    this.audioScript,
  });

  final String name;
  final String speechCode;
  final String languageLabel;
  final String listenLabel;
  final String stopAudioLabel;
  final String savingLabel;
  final String acceptLabel;
  final String titlePrefix;
  final String intro;
  final String profileTitle;
  final String profileBody;
  final String identityTitle;
  final String identityBody;
  final String payoutTitle;
  final String payoutBody;
  final String operationsTitle;
  final String operationsBody;
  final String correctionTitle;
  final String correctionBody;
  final String? audioScript;

  String title(String partnerName) => '$titlePrefix, $partnerName';

  String audioText(String partnerName) {
    final script = audioScript;
    if (script != null) {
      return script.replaceAll('{partnerName}', partnerName);
    }

    return [
      title(partnerName),
      intro,
      profileTitle,
      profileBody,
      identityTitle,
      identityBody,
      payoutTitle,
      payoutBody,
      operationsTitle,
      operationsBody,
      correctionTitle,
      correctionBody,
    ].join('. ');
  }

  Duration get estimatedDuration {
    final runeCount = audioText('').runes.length;
    final seconds = (runeCount / 12).ceil().clamp(16, 90);
    return Duration(seconds: seconds);
  }
}

const List<_ConsentLanguage> _consentLanguages = [
  _ConsentLanguage(
    name: 'English',
    speechCode: 'en-IN',
    languageLabel: 'Consent language',
    listenLabel: 'Listen to consent',
    stopAudioLabel: 'Stop audio',
    savingLabel: 'Saving...',
    acceptLabel: 'I agree and continue',
    titlePrefix: 'Before you start',
    intro:
        'Please review and accept how MaidItQuick will use your information for Partner onboarding.',
    profileTitle: 'Profile details',
    profileBody:
        'We ask for your name, gender, date of birth and profile photo to personalise services, verify eligibility and keep you and our customers safe.',
    identityTitle: 'Identity and safety review',
    identityBody:
        'We collect identity documents, PAN, selfie and address proof only to review Partner eligibility.',
    payoutTitle: 'Payout setup',
    payoutBody:
        'We collect bank or UPI details so payouts can be reviewed and configured after approval.',
    operationsTitle: 'Operations access',
    operationsBody:
        'MaidItQuick operations reviewers can approve, reject or request resubmission for required checks.',
    correctionTitle: 'Correction and deletion',
    correctionBody:
        'You can request correction or deletion through support, subject to operational and legal retention needs.',
  ),
  _ConsentLanguage(
    name: 'हिन्दी',
    speechCode: 'hi-IN',
    languageLabel: 'सहमति की भाषा',
    listenLabel: 'सहमति सुनें',
    stopAudioLabel: 'ऑडियो रोकें',
    savingLabel: 'सेव हो रहा है...',
    acceptLabel: 'मैं सहमत हूं और आगे बढ़ना चाहती/चाहता हूं',
    titlePrefix: 'शुरू करने से पहले',
    intro:
        'कृपया पढ़ें और स्वीकार करें कि MaidItQuick पार्टनर ऑनबोर्डिंग के लिए आपकी जानकारी का उपयोग कैसे करेगा।',
    profileTitle: 'प्रोफ़ाइल विवरण',
    profileBody:
        'हम सेवाओं को निजीकृत करने, पात्रता सत्यापित करने और आपकी तथा हमारे ग्राहकों की सुरक्षा के लिए आपका नाम, लिंग, जन्म तिथि और प्रोफ़ाइल फोटो मांगते हैं।',
    identityTitle: 'पहचान और सुरक्षा समीक्षा',
    identityBody:
        'हम पार्टनर पात्रता की समीक्षा के लिए ही पहचान दस्तावेज़, PAN, सेल्फी और पते का प्रमाण लेते हैं।',
    payoutTitle: 'पेआउट सेटअप',
    payoutBody:
        'हम बैंक या UPI विवरण लेते हैं ताकि मंजूरी के बाद पेआउट की समीक्षा और सेटअप किया जा सके।',
    operationsTitle: 'ऑपरेशंस एक्सेस',
    operationsBody:
        'MaidItQuick ऑपरेशंस समीक्षक जरूरी जांचों को मंजूर, अस्वीकार या दोबारा जमा करने के लिए कह सकते हैं।',
    correctionTitle: 'सुधार और हटाने का अनुरोध',
    correctionBody:
        'आप सपोर्ट के माध्यम से सुधार या हटाने का अनुरोध कर सकते हैं, जो संचालन और कानूनी रखरखाव जरूरतों पर निर्भर होगा।',
  ),
  _ConsentLanguage(
    name: 'मराठी',
    speechCode: 'hi-IN',
    languageLabel: 'संमतीची भाषा',
    listenLabel: 'संमती ऐका',
    stopAudioLabel: 'ऑडिओ थांबवा',
    savingLabel: 'सेव्ह होत आहे...',
    acceptLabel: 'मी सहमत आहे आणि पुढे सुरू ठेवतो',
    titlePrefix: 'सुरुवात करण्यापूर्वी',
    intro:
        'कृपया वाचा आणि मान्य करा की MaidItQuick पार्टनर ऑनबोर्डिंगसाठी तुमची माहिती कशी वापरेल.',
    profileTitle: 'प्रोफाइल तपशील',
    profileBody:
        'सेवा वैयक्तिकृत करण्यासाठी, पात्रता सत्यापित करण्यासाठी आणि तुमची व आमच्या ग्राहकांची सुरक्षा सुनिश्चित करण्यासाठी आम्ही तुमचे नाव, लिंग, जन्मतारीख आणि प्रोफाइल फोटो विचारतो.',
    identityTitle: 'ओळख आणि सुरक्षा तपासणी',
    identityBody:
        'पार्टनर पात्रता तपासण्यासाठीच आम्ही ओळखपत्रे, PAN, सेल्फी आणि पत्त्याचा पुरावा घेतो.',
    payoutTitle: 'पेआउट सेटअप',
    payoutBody:
        'मंजुरीनंतर पेआउट तपासणी आणि सेटअप करण्यासाठी आम्ही बँक किंवा UPI तपशील घेतो.',
    operationsTitle: 'ऑपरेशन्स प्रवेश',
    operationsBody:
        'MaidItQuick ऑपरेशन्स टीम आवश्यक तपासण्या मंजूर करू शकते, नाकारू शकते किंवा पुन्हा सबमिट करण्यास सांगू शकते.',
    correctionTitle: 'सुधारणा किंवा हटवण्याची विनंती',
    correctionBody:
        'तुम्ही सपोर्टद्वारे माहिती सुधारण्याची किंवा हटवण्याची विनंती करू शकता. ही विनंती ऑपरेशनल आणि कायदेशीर जतन गरजांवर अवलंबून असेल.',
    audioScript:
        'सुरुवात करण्यापूर्वी, {partnerName}. कृपया वाचा आणि मान्य करा की मेड इट क्विक पार्टनर ऑनबोर्डिंगसाठी तुमची माहिती कशी वापरेल. प्रोफाइल तपशील. सेवा वैयक्तिकृत करण्यासाठी, पात्रता सत्यापित करण्यासाठी आणि तुमची व आमच्या ग्राहकांची सुरक्षा सुनिश्चित करण्यासाठी आम्ही तुमचे नाव, लिंग, जन्मतारीख आणि प्रोफाइल फोटो विचारतो. ओळख आणि सुरक्षा तपासणी. पार्टनर पात्रता तपासण्यासाठीच आम्ही ओळखपत्रे, पॅन, सेल्फी आणि पत्त्याचा पुरावा घेतो. पेआउट सेटअप. मंजुरीनंतर पेआउट तपासणी आणि सेटअप करण्यासाठी आम्ही बँक किंवा यू पी आय तपशील घेतो. ऑपरेशन्स प्रवेश. मेड इट क्विक ऑपरेशन्स टीम आवश्यक तपासण्या मंजूर करू शकते, नाकारू शकते, किंवा पुन्हा सबमिट करण्यास सांगू शकते. सुधारणा किंवा हटवण्याची विनंती. तुम्ही सपोर्टद्वारे माहिती सुधारण्याची किंवा हटवण्याची विनंती करू शकता. ही विनंती ऑपरेशनल आणि कायदेशीर जतन गरजांवर अवलंबून असेल.',
  ),
  _ConsentLanguage(
    name: 'বাংলা',
    speechCode: 'bn-IN',
    languageLabel: 'সম্মতির ভাষা',
    listenLabel: 'সম্মতি শুনুন',
    stopAudioLabel: 'অডিও বন্ধ করুন',
    savingLabel: 'সেভ হচ্ছে...',
    acceptLabel: 'আমি সম্মত এবং এগিয়ে যেতে চাই',
    titlePrefix: 'শুরু করার আগে',
    intro:
        'MaidItQuick পার্টনার অনবোর্ডিংয়ের জন্য আপনার তথ্য কীভাবে ব্যবহার করবে, অনুগ্রহ করে তা পড়ে সম্মতি দিন।',
    profileTitle: 'প্রোফাইল বিবরণ',
    profileBody:
        'সেবা ব্যক্তিগতকরণ, যোগ্যতা যাচাই এবং আপনার ও আমাদের গ্রাহকদের নিরাপত্তা নিশ্চিত করতে আমরা আপনার নাম, লিঙ্গ, জন্ম তারিখ এবং প্রোফাইল ছবি চাই।',
    identityTitle: 'পরিচয় এবং নিরাপত্তা যাচাই',
    identityBody:
        'পার্টনার যোগ্যতা যাচাই করার জন্যই আমরা পরিচয়পত্র, PAN, সেলফি এবং ঠিকানার প্রমাণ সংগ্রহ করি।',
    payoutTitle: 'পেআউট সেটআপ',
    payoutBody:
        'অনুমোদনের পরে পেআউট যাচাই ও সেটআপ করার জন্য আমরা ব্যাংক বা UPI তথ্য সংগ্রহ করি।',
    operationsTitle: 'অপারেশনস অ্যাক্সেস',
    operationsBody:
        'MaidItQuick অপারেশনস রিভিউয়াররা প্রয়োজনীয় যাচাই অনুমোদন, প্রত্যাখ্যান বা পুনরায় জমা দিতে বলতে পারেন।',
    correctionTitle: 'সংশোধন এবং মুছে ফেলার অনুরোধ',
    correctionBody:
        'আপনি সাপোর্টের মাধ্যমে সংশোধন বা মুছে ফেলার অনুরোধ করতে পারেন; এটি অপারেশনাল এবং আইনি সংরক্ষণ প্রয়োজনের উপর নির্ভর করবে।',
    audioScript:
        'शुरु करार आगे, {partnerName}. मेड इट कुइक पार्टनर अनबोर्डिंगर जन्य आपनार तथ्य किभाबे बाबोहार करबे, अनुग्रह करे ता पोरे सम्मति दिन. प्रोफाइल बिबरन. सेवा ब्यक्तिगतकरण, जोग्गोता जाचाई एबं आपनार ओ आमादेर ग्राहकदेर निरापोत्ता निश्चित करते आम्रा आपनार नाम, लिंगो, जन्म तारिख एबं प्रोफाइल छबि चाई. परिचय एबं निरापोत्ता जाचाई. पार्टनर जोग्गोता जाचाई करार जन्योई आम्रा परिचयपत्र, पैन, सेल्फी एबं ठिकानार प्रमाण संग्रह करि. पेआउट सेटआप. अनुमोदनेर पोरे पेआउट जाचाई ओ सेटआप करार जन्य आम्रा ब्यांक बा यू पी आय तथ्य संग्रह करि. ऑपरेशन्स एक्सेस. मेड इट कुइक ऑपरेशन्स रिव्यूयारा प्रयोजनीय जाचाई अनुमोदन, प्रत्याख्यान बा पुनराय जमा दिते बोलते पारेन. संशोधन एबं मुचे फेलार अनुरोध. आपनि सपोर्टेर माध्यमे संशोधन बा मुचे फेलार अनुरोध करते पारेन; एटि ऑपरेशनल एबं आइनि संरक्षण प्रयोजनेर उपर निर्भर करबे.',
  ),
];

class _ConsentPoint extends StatelessWidget {
  const _ConsentPoint(
      {required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: BrandColors.lime),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(body,
                  style:
                      const TextStyle(color: BrandColors.muted, height: 1.35)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _PartnerStatusCard extends StatelessWidget {
  const _PartnerStatusCard(
      {required this.title, required this.status, required this.icon});
  final String title;
  final String status;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final approved = status == 'APPROVED' || status == 'AVAILABLE';
    final pending = status == 'PENDING';
    final color = approved
        ? BrandColors.lime
        : pending
            ? Colors.amber
            : BrandColors.muted;
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(status.replaceAll('_', ' '),
            style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
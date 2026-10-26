import 'package:flutter/material.dart';
import 'package:philippines_rpcmb/philippines_rpcmb.dart';

import '../../../core/constants/app_colors.dart';
import '../../explore/screens/explore_page.dart';
import '../providers/get_started_form_controller.dart';
import '../services/auth_service.dart';
import '../widgets/login_field_section.dart';

/// Profile setup form that collects the user's basic onboarding details.
class GetStartedPage extends StatefulWidget {
  const GetStartedPage({super.key});

  /// Route name used for the onboarding profile-setup screen.
  static const routeName = '/get-started';

  @override
  // Creates the state object that owns the form controller and text controller.
  State<GetStartedPage> createState() => _GetStartedPageState();
}

/// State holder for the multi-field onboarding form.
class _GetStartedPageState extends State<GetStartedPage> {
  /// Controller that stores the onboarding selections and derived city list.
  late final GetStartedFormController _controller;

  /// Text controller bound to the username input field.
  late final TextEditingController _usernameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _contactNumberController;
  late final TextEditingController _zipCodeController;
  final _authService = AuthService();
  bool _isSubmitting = false;

  @override
  // Initializes controllers for the form fields and reactive state updates.
  void initState() {
    super.initState();
    _controller = GetStartedFormController();
    _usernameController = TextEditingController();
    _lastNameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _contactNumberController = TextEditingController();
    _zipCodeController = TextEditingController();
  }

  @override
  // Releases both controllers when the page is removed from the tree.
  void dispose() {
    _usernameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _contactNumberController.dispose();
    _zipCodeController.dispose();
    _authService.dispose();
    _controller.dispose();
    super.dispose();
  }

  // Builds the filled input decoration used by dropdowns and the birthday field.
  InputDecoration _filledDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: AppColors.gray, fontSize: 14),
      filled: true,
      fillColor: AppColors.softBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.green, width: 1.2),
      ),
    );
  }

  // Builds the underline style used by the username field.
  InputDecoration _underlineDecoration({required String hintText}) {
    return const InputDecoration().copyWith(
      hintText: hintText,
      hintStyle: const TextStyle(color: AppColors.gray, fontSize: 14),
      contentPadding: const EdgeInsets.only(bottom: 10),
      border: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.border, width: 1.2),
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.border, width: 1.2),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.green, width: 1.4),
      ),
    );
  }

  Future<void> _createAccount() async {
    final firstName = _usernameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final contactNumber = _contactNumberController.text.trim();
    final region = _controller.selectedRegion;
    final province = _controller.selectedProvince;
    final city = _controller.selectedCity;
    final zipCode = _zipCodeController.text.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        contactNumber.isEmpty ||
        region == null ||
        city == null ||
        zipCode.isEmpty ||
        (!(_controller.isNcr) && province == null)) {
      _showMessage('Please complete all account and address fields');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _authService.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        contactNumber: contactNumber,
        region: region.regionName,
        province: _controller.isNcr ? '' : province!.name,
        cityMunicipality: city.name,
        zipCode: zipCode,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder:
              (_) => ExplorePage(
                initialLocationLabel:
                    _controller.selectedCity?.name ??
                    _controller.selectedRegion?.regionName ??
                    ExplorePage.defaultLocationLabel,
              ),
        ),
      );
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  // Builds the full onboarding form and connects each input to the controller.
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 46,
                ),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Let\'s get you started',
                          style: TextStyle(
                            color: AppColors.black,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'I just wanna know you better, know you better, know you better now',
                          style: TextStyle(
                            color: AppColors.gray,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 20),
                        LoginFieldSection(
                          label: 'First name',
                          child: TextFormField(
                            controller: _usernameController,
                            onChanged: _controller.setUsername,
                            decoration: _underlineDecoration(
                              hintText: 'Write your first name here',
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        LoginFieldSection(
                          label: 'Last name',
                          child: TextFormField(
                            controller: _lastNameController,
                            decoration: _underlineDecoration(
                              hintText: 'Write your last name here',
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        LoginFieldSection(
                          label: 'Email',
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _underlineDecoration(
                              hintText: 'you@example.com',
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        LoginFieldSection(
                          label: 'Password',
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: _underlineDecoration(
                              hintText: 'Choose a password',
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        LoginFieldSection(
                          label: 'Contact number',
                          child: TextFormField(
                            controller: _contactNumberController,
                            keyboardType: TextInputType.phone,
                            decoration: _underlineDecoration(
                              hintText: '09XXXXXXXXX',
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        LoginFieldSection(
                          label: 'Region',
                          child: DropdownButtonFormField<Region>(
                            key: ValueKey(_controller.selectedRegion?.id),
                            value: _controller.selectedRegion,
                            items: _controller.regions
                                .map(
                                  (region) => DropdownMenuItem<Region>(
                                    value: region,
                                    child: Text(region.regionName),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: _controller.setRegion,
                            decoration: _filledDecoration(
                              hintText: 'Select your region',
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            menuMaxHeight: 320,
                            isExpanded: true,
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (!_controller.isNcr)
                          LoginFieldSection(
                            label: 'Province',
                            child: DropdownButtonFormField<Province>(
                              key: ValueKey(_controller.selectedProvince?.id),
                              value: _controller.selectedProvince,
                              items: _controller.availableProvinces
                                  .map(
                                    (province) => DropdownMenuItem<Province>(
                                      value: province,
                                      child: Text(province.name),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged:
                                  _controller.selectedRegion == null
                                      ? null
                                      : _controller.setProvince,
                              decoration: _filledDecoration(
                                hintText:
                                    _controller.selectedRegion == null
                                        ? 'Select a region first'
                                        : 'Select your province',
                              ),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                              ),
                              menuMaxHeight: 320,
                              isExpanded: true,
                            ),
                          ),
                        if (!_controller.isNcr) const SizedBox(height: 18),
                        LoginFieldSection(
                          label: 'City',
                          child: DropdownButtonFormField<Municipality>(
                            key: ValueKey(
                              '${_controller.selectedRegion?.id}:${_controller.selectedProvince?.id}',
                            ),
                            value: _controller.selectedCity,
                            items: _controller.availableCities
                                .map(
                                  (city) => DropdownMenuItem<Municipality>(
                                    value: city,
                                    child: Text(city.name),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged:
                                (_controller.selectedRegion == null ||
                                        (!_controller.isNcr &&
                                            _controller.selectedProvince ==
                                                null))
                                    ? null
                                    : _controller.setCity,
                            decoration: _filledDecoration(
                              hintText:
                                  _controller.selectedRegion == null
                                      ? 'Select a region first'
                                      : (!_controller.isNcr &&
                                          _controller.selectedProvince == null)
                                      ? 'Select a province first'
                                      : 'Select your city',
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            menuMaxHeight: 320,
                            isExpanded: true,
                          ),
                        ),
                        const SizedBox(height: 18),
                        LoginFieldSection(
                          label: 'ZIP code',
                          child: TextFormField(
                            controller: _zipCodeController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            decoration: _underlineDecoration(
                              hintText: 'e.g. 1000',
                            ).copyWith(counterText: ''),
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.green,
                              foregroundColor: AppColors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isSubmitting ? null : _createAccount,
                            child: const Text(
                              'Create account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:philippines_rpcmb/philippines_rpcmb.dart';

import '../../../core/constants/app_colors.dart';
import '../../explore/screens/explore_page.dart';
import '../providers/get_started_form_controller.dart';
import '../services/auth_service.dart';
import '../widgets/choice_pill_group.dart';
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
  }

  @override
  // Releases both controllers when the page is removed from the tree.
  void dispose() {
    _usernameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _contactNumberController.dispose();
    _authService.dispose();
    _controller.dispose();
    super.dispose();
  }

  // Shows the date picker and stores the birthday once the user confirms a date.
  Future<void> _pickBirthday() async {
    final today = DateTime.now();
    final initialDate = _controller.selectedBirthday ?? DateTime(today.year - 18, today.month, today.day);
    final firstDate = DateTime(1900);

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: today,
      helpText: 'Select your birth date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.green,
                  onPrimary: AppColors.white,
                  surface: AppColors.white,
                ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (!mounted || selectedDate == null) {
      return;
    }

    _controller.setBirthday(selectedDate);
  }

  // Formats the selected birthday for display inside the input decorator.
  String _birthdayText(BuildContext context) {
    final birthday = _controller.selectedBirthday;
    if (birthday == null) {
      return 'Select your birthday';
    }

    return MaterialLocalizations.of(context).formatMediumDate(birthday);
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

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || password.isEmpty || contactNumber.isEmpty) {
      _showMessage('Please complete all account fields');
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
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ExplorePage(
            initialLocationLabel: _controller.selectedCity?.name ??
                _controller.selectedRegion?.regionName ??
                'Caybiga',
          ),
        ),
      );
    } catch (error) {
      if (mounted) _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 46),
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
                            decoration: _underlineDecoration(hintText: 'Write your last name here'),
                          ),
                        ),
                        const SizedBox(height: 22),
                        LoginFieldSection(
                          label: 'Email',
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _underlineDecoration(hintText: 'you@example.com'),
                          ),
                        ),
                        const SizedBox(height: 22),
                        LoginFieldSection(
                          label: 'Password',
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: _underlineDecoration(hintText: 'Choose a password'),
                          ),
                        ),
                        const SizedBox(height: 22),
                        LoginFieldSection(
                          label: 'Contact number',
                          child: TextFormField(
                            controller: _contactNumberController,
                            keyboardType: TextInputType.phone,
                            decoration: _underlineDecoration(hintText: '09XXXXXXXXX'),
                          ),
                        ),
                        const SizedBox(height: 22),
                        LoginFieldSection(
                          label: 'Sex',
                          helperText: 'For your eyes only...',
                          child: ChoicePillGroup<Gender>(
                            options: const [
                              ChoicePillOption(label: 'Female', value: Gender.female),
                              ChoicePillOption(label: 'Male', value: Gender.male),
                              ChoicePillOption(
                                label: 'Prefer not to say',
                                value: Gender.preferNotToSay,
                              ),
                            ],
                            value: _controller.selectedGender,
                            onChanged: _controller.setGender,
                          ),
                        ),
                        const SizedBox(height: 22),
                        LoginFieldSection(
                          label: 'Birthday',
                          footerText: 'For your eyes only...',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: _pickBirthday,
                            child: InputDecorator(
                              decoration: _filledDecoration(hintText: 'Select your birthday'),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _birthdayText(context),
                                      style: TextStyle(
                                        color: _controller.selectedBirthday == null
                                            ? AppColors.gray
                                            : AppColors.black,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 18,
                                    color: AppColors.gray,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        LoginFieldSection(
                          label: 'Region',
                          child: DropdownButtonFormField<Region>(
                            initialValue: _controller.selectedRegion,
                            items: _controller.regions
                                .map(
                                  (region) => DropdownMenuItem<Region>(
                                    value: region,
                                    child: Text(region.regionName),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: _controller.setRegion,
                            decoration: _filledDecoration(hintText: 'Select your region'),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            menuMaxHeight: 320,
                            isExpanded: true,
                          ),
                        ),
                        const SizedBox(height: 18),
                        LoginFieldSection(
                          label: 'City',
                          child: DropdownButtonFormField<Municipality>(
                            initialValue: _controller.selectedCity,
                            items: _controller.availableCities
                                .map(
                                  (city) => DropdownMenuItem<Municipality>(
                                    value: city,
                                    child: Text(city.name),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: _controller.selectedRegion == null ? null : _controller.setCity,
                            decoration: _filledDecoration(
                              hintText: _controller.selectedRegion == null
                                  ? 'Select a region first'
                                  : 'Select your city',
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            menuMaxHeight: 320,
                            isExpanded: true,
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
import 'package:flutter/material.dart';

/// Formulaire pour saisir les informations de l'entreprise pour la facture
class InvoiceForm extends StatefulWidget {
  final String companyName;
  final String companyAddress;
  final String companyPhone;
  final String companyEmail;
  final String taxNumber;
  final ValueChanged<String> onCompanyNameChanged;
  final ValueChanged<String> onCompanyAddressChanged;
  final ValueChanged<String> onCompanyPhoneChanged;
  final ValueChanged<String> onCompanyEmailChanged;
  final ValueChanged<String> onTaxNumberChanged;

  const InvoiceForm({
    super.key,
    required this.companyName,
    required this.companyAddress,
    required this.companyPhone,
    required this.companyEmail,
    required this.taxNumber,
    required this.onCompanyNameChanged,
    required this.onCompanyAddressChanged,
    required this.onCompanyPhoneChanged,
    required this.onCompanyEmailChanged,
    required this.onTaxNumberChanged,
  });

  @override
  State<InvoiceForm> createState() => _InvoiceFormState();
}

class _InvoiceFormState extends State<InvoiceForm> {
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _taxController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.companyName);
    _addressController = TextEditingController(text: widget.companyAddress);
    _phoneController = TextEditingController(text: widget.companyPhone);
    _emailController = TextEditingController(text: widget.companyEmail);
    _taxController = TextEditingController(text: widget.taxNumber);
  }

  @override
  void didUpdateWidget(InvoiceForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyName != widget.companyName) {
      _nameController.text = widget.companyName;
    }
    if (oldWidget.companyAddress != widget.companyAddress) {
      _addressController.text = widget.companyAddress;
    }
    if (oldWidget.companyPhone != widget.companyPhone) {
      _phoneController.text = widget.companyPhone;
    }
    if (oldWidget.companyEmail != widget.companyEmail) {
      _emailController.text = widget.companyEmail;
    }
    if (oldWidget.taxNumber != widget.taxNumber) {
      _taxController.text = widget.taxNumber;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _taxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informations de l\'entreprise',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Nom de l'entreprise
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Nom de l\'entreprise',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.business),
          ),
          onChanged: widget.onCompanyNameChanged,
        ),
        const SizedBox(height: 12),
        
        // Adresse
        TextField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Adresse',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on),
          ),
          onChanged: widget.onCompanyAddressChanged,
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        
        // Téléphone
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Téléphone',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
          ),
          onChanged: widget.onCompanyPhoneChanged,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        
        // Email
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email),
          ),
          onChanged: widget.onCompanyEmailChanged,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        
        // Numéro de taxe
        TextField(
          controller: _taxController,
          decoration: const InputDecoration(
            labelText: 'Numéro de taxe',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.receipt),
          ),
          onChanged: widget.onTaxNumberChanged,
        ),
      ],
    );
  }
}



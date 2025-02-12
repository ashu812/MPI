import 'package:flutter/material.dart';

class StylishTextField extends StatelessWidget {
  final String hintText;
  final TextEditingController controller;
  final Color backgroundColor;
  final bool obscureText;
  final Color textColor;

  const StylishTextField({
    super.key,
    required this.hintText,
    required this.controller,
    this.obscureText = false,
    this.textColor = Colors.black,
    required this.backgroundColor,
    required int borderRadius,
    required MaterialColor borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle:
              TextStyle(color: Colors.grey[800]), // Darker for readability
          filled: true,
          fillColor: Colors.white.withOpacity(0.85), // Semi-transparent white
          contentPadding:
              const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: const BorderSide(color: Colors.white54, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
          ),
          suffixIcon: obscureText
              ? Icon(Icons.lock_outline, color: Colors.grey[700])
              : Icon(Icons.text_fields, color: Colors.grey[700]),
        ),
      ),
    );
  }
}

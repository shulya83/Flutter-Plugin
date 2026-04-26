import 'package:flutter/material.dart';

class LocalInputProbe extends StatelessWidget {
  const LocalInputProbe({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: 'Local text input',
        prefixIcon: const Icon(Icons.keyboard_alt_outlined),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD6DEE6)),
        ),
      ),
    );
  }
}

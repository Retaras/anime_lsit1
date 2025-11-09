import 'package:flutter/material.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Экран поиска', style: TextStyle(color: Colors.white)),
      ),
      body: const Center(
        child: Text(
          'Здесь будет расширенный поиск аниме',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}

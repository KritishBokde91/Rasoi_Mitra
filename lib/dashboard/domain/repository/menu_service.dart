import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import '../entities/menu_item.dart';

class MenuService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch weekly menu (all days) from Firestore
  Future<Map<String, Map<String, List<MenuItem>>>?> getWeeklyMenu() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('menu').get();

      Map<String, Map<String, List<MenuItem>>> weeklyMenu = {};

      for (var doc in snapshot.docs) {
        String day = doc.id; // Use doc.id to get the day (e.g., 'Monday')
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        Map<String, List<MenuItem>> meals = {
          'Breakfast': _convertToMenuItems(data['Breakfast']),
          'Lunch': _convertToMenuItems(data['Lunch']),
          'Dinner': _convertToMenuItems(data['Dinner']),
        };

        weeklyMenu[day] = meals;
      }

      return weeklyMenu;
    } catch (e) {
      debugPrint('Error fetching menu: $e');
      return null;
    }
  }

  // Fetch menu for a specific day
  Future<Map<String, List<MenuItem>>?> getMenuForDay(String day) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('menu').doc(day).get();

      if (!doc.exists) {
        debugPrint('No menu found for $day');
        return null;
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      return {
        'Breakfast': _convertToMenuItems(data['Breakfast']),
        'Lunch': _convertToMenuItems(data['Lunch']),
        'Dinner': _convertToMenuItems(data['Dinner']),
      };
    } catch (e) {
      debugPrint('Error fetching menu for $day: $e');
      return null;
    }
  }

  // Helper function to convert Firestore data to List<MenuItem>
  List<MenuItem> _convertToMenuItems(List<dynamic>? items) {
    if (items == null) return [];
    return items.map((item) {
      return MenuItem(
        name: item['name'] ?? '',
        price: item['price']?.toDouble() ?? 0.0,
        image: item['image'] ?? '',
        imageUrl: item['imageUrl'] ?? '',
        description: item['description'] ?? 'Delicious homemade meal',
      );
    }).toList();
  }

  // Set menu data in Firestore
  Future<void> setMenuData(
      Map<String, Map<String, List<MenuItem>>> weeklyMenu) async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('menu').get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      // Add new menu data
      for (var day in weeklyMenu.keys) {
        await _firestore.collection('menu').doc(day).set({
          'Breakfast': weeklyMenu[day]!['Breakfast']!
              .map(
                (item) => {
              'name': item.name,
              'price': item.price,
              'image': item.image,
              'imageUrl': item.imageUrl,
              'description': item.description,
            },
          )
              .toList(),
          'Lunch': weeklyMenu[day]!['Lunch']!
              .map(
                (item) => {
              'name': item.name,
              'price': item.price,
              'image': item.image,
              'imageUrl': item.imageUrl,
              'description': item.description,
            },
          )
              .toList(),
          'Dinner': weeklyMenu[day]!['Dinner']!
              .map(
                (item) => {
              'name': item.name,
              'price': item.price,
              'image': item.image,
              'imageUrl': item.imageUrl,
              'description': item.description,
            },
          )
              .toList(),
        });
      }
      debugPrint('Menu data successfully added to Firestore!');
    } catch (e) {
      debugPrint('Error setting menu data: $e');
    }
  }
}
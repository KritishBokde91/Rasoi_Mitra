class MenuItem {
  final String name;
  final double price;
  final String image; // emoji representation
  final String imageUrl; // actual food image URL
  final String description;

  MenuItem({
    required this.name,
    required this.price,
    required this.image,
    required this.imageUrl,
    this.description = 'Delicious homemade meal',
  });

  Map<String, dynamic> toJson() {
    return {'name': name, 'price': price, 'image': image, 'imageUrl': imageUrl};
  }

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      image: json['image'] ?? '🍽️',
      imageUrl:
          json['imageUrl'] ??
          'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=300&h=300&fit=crop&crop=center',
      description: 'Delicious homemade meal',
    );
  }

  @override
  String toString() {
    return 'MenuItem(name: $name, price: $price, image: $image, imageUrl: $imageUrl, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MenuItem &&
        other.name == name &&
        other.price == price &&
        other.image == image &&
        other.imageUrl == imageUrl &&
        other.description == description;
  }

  @override
  int get hashCode {
    return name.hashCode ^ price.hashCode ^ image.hashCode ^ imageUrl.hashCode;
  }
}

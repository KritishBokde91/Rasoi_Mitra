class BookingItem {
  final String id;
  final String mealType;
  final String item;
  final DateTime bookingTime;
  final DateTime deliveryDate;
  final String status;
  final double price;
  final int quantity;
  final String address;
  final String paymentMethod;
  final String? paymentId;
  final double? latitude;
  final double? longitude;
  final bool isCustom;

  BookingItem({
    required this.id,
    required this.mealType,
    required this.item,
    required this.bookingTime,
    required this.deliveryDate,
    required this.status,
    required this.price,
    required this.quantity,
    required this.address,
    required this.paymentMethod,
    this.paymentId,
    this.latitude,
    this.longitude,
    this.isCustom = false,
  });

  // Convert BookingItem to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mealType': mealType,
      'item': item,
      'bookingTime': bookingTime.toIso8601String(),
      'deliveryDate': deliveryDate.toIso8601String(),
      'status': status,
      'price': price,
      'quantity': quantity,
      'address': address,
      'paymentMethod': paymentMethod,
      'paymentId': paymentId,
      'latitude': latitude,
      'longitude': longitude,
      'isCustom': isCustom,
    };
  }

  // Create BookingItem from Map
  factory BookingItem.fromMap(Map<String, dynamic> map) {
    return BookingItem(
      id: map['id'] ?? '',
      mealType: map['mealType'] ?? '',
      item: map['item'] ?? '',
      bookingTime: DateTime.parse(map['bookingTime']),
      deliveryDate: DateTime.parse(map['deliveryDate']),
      status: map['status'] ?? 'Pending',
      price: (map['price'] ?? 0.0).toDouble(),
      quantity: map['quantity'] ?? 1,
      address: map['address'] ?? '',
      paymentMethod: map['paymentMethod'] ?? 'cod',
      paymentId: map['paymentId'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      isCustom: map['isCustom'] ?? false,
    );
  }

  // Create a copy with updated fields
  BookingItem copyWith({
    String? id,
    String? mealType,
    String? item,
    DateTime? bookingTime,
    DateTime? deliveryDate,
    String? status,
    double? price,
    int? quantity,
    String? address,
    String? paymentMethod,
    String? paymentId,
    double? latitude,
    double? longitude,
    bool? isCustom,
  }) {
    return BookingItem(
      id: id ?? this.id,
      mealType: mealType ?? this.mealType,
      item: item ?? this.item,
      bookingTime: bookingTime ?? this.bookingTime,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      status: status ?? this.status,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      address: address ?? this.address,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentId: paymentId ?? this.paymentId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  @override
  String toString() {
    return 'BookingItem{id: $id, mealType: $mealType, item: $item, status: $status, price: $price, quantity: $quantity, address: $address, paymentMethod: $paymentMethod, isCustom: $isCustom}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookingItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
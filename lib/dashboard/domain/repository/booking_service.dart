import '../entities/booking_item.dart';

class BookingService {
  static List<BookingItem> bookings = [];

  static void addBooking(BookingItem booking) {
    bookings.add(booking);
  }

  static List<BookingItem> getBookings() {
    return bookings;
  }

  static List<BookingItem> getPendingBookings() {
    return bookings.where((b) => b.status == 'Pending').toList();
  }

  static List<BookingItem> getConfirmedBookings() {
    return bookings.where((b) => b.status == 'Confirmed').toList();
  }
}
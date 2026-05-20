# Product Order Provider API Spec

This document defines the backend APIs needed for the Flutter provider app to build a product order/delivery flow almost the same as the existing booking flow.

The current product APIs (`user-product-list`, `product-save`, `product-update`, `product-delete`) manage the provider product catalog only. The app also needs product order APIs for accepting orders, assigning delivery, tracking location, marking delivery, and viewing order detail.

## Goal

Provider should be able to:

- View product orders.
- Accept or reject product orders.
- Assign the order to himself.
- Assign the order to a delivery boy. Delivery boy is the existing `handyman` user type.
- Start delivery/drive.
- Update live location.
- Track assigned delivery boy on map.
- Mark order delivered/completed.
- View customer, address, products, payment, delivery boy, proof, and status history.

## Auth And Format

All endpoints require:

```http
Authorization: Bearer <sanctum_token>
Accept: application/json
```

Use `multipart/form-data` only when uploading proof/images. Other endpoints can use JSON.

## Status Lifecycle

Recommended statuses:

| Status | Meaning |
| --- | --- |
| `pending` | New product order waiting for provider action. |
| `accept` | Provider accepted the order. |
| `assigned` | Provider assigned himself or a delivery boy. |
| `on_going` | Delivery started / start drive. Location tracking active. |
| `delivered` | Delivery boy/provider marked delivered. |
| `completed` | Order fully completed/closed. |
| `cancelled` | Cancelled by customer/admin/provider according to rules. |
| `rejected` | Provider rejected the order. |

If backend prefers fewer statuses, `accept` can mean accepted but unassigned, and assignment can still be detected from `handyman_id`.

## 1. Product Order Listing

`GET /api/provider-product-order-list`

Returns product orders owned by the logged-in provider.

Query params:

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `page` | integer | no | Pagination page. |
| `per_page` | integer/string | no | Use app default if missing. |
| `status` | string | no | `pending`, `accept`, `assigned`, `on_going`, `delivered`, `completed`, `cancelled`, `rejected`. |
| `payment_status` | string | no | `paid`, `pending`, `pending_by_admin`, etc. |
| `payment_type` | string | no | `cash`, `wallet`, `stripe`, etc. |
| `date_from` | string | no | `yyyy-MM-dd`. |
| `date_to` | string | no | `yyyy-MM-dd`. |
| `customer_id` | integer/string | no | Single id or comma-separated ids. |
| `handyman_id` | integer/string | no | Existing handyman user id, used as delivery boy id. |
| `shop_id` | integer/string | no | Shop filter. |
| `search` | string | no | Search order id, product name, customer name. |

Success response:

```json
{
  "status": true,
  "data": [
    {
      "id": 101,
      "order_code": "PO-101",
      "status": "pending",
      "status_label": "Pending",
      "payment_status": "pending",
      "payment_method": "cash",
      "total_amount": 1450,
      "total_amount_format": "$1,450.00",
      "date": "2026-05-17 14:30:00",
      "customer_id": 22,
      "customer_name": "Ali Khan",
      "customer_image": "https://example.com/storage/customer.jpg",
      "customer_phone": "+923001234567",
      "delivery_address": "House 12, Street 4, Karachi",
      "delivery_latitude": "24.8607",
      "delivery_longitude": "67.0011",
      "shop_id": 5,
      "shop_name": "Main Shop",
      "handyman_id": null,
      "delivery_boy": null,
      "product_image": "https://example.com/storage/product.jpg",
      "product_count": 2,
      "items": [
        {
          "id": 1,
          "product_id": 12,
          "name": "Cricket Ball",
          "image": "https://example.com/storage/product.jpg",
          "quantity": 2,
          "price": 250,
          "price_format": "$250.00",
          "variant_label": "Color: Red"
        }
      ]
    }
  ],
  "total_earning": "1450",
  "payment_breakdown": {
    "cash": 1450,
    "online": 0,
    "wallet": 0
  },
  "pagination": {
    "total_items": 1,
    "per_page": 15,
    "currentPage": 1,
    "totalPages": 1
  }
}
```

## 2. Product Order Detail

`POST /api/product-order-detail`

Payload:

```json
{
  "id": 101
}
```

Success response:

```json
{
  "status": true,
  "data": {
    "id": 101,
    "order_code": "PO-101",
    "status": "accept",
    "status_label": "Accepted",
    "date": "2026-05-17 14:30:00",
    "description": "Leave at reception if unavailable.",
    "payment_id": 555,
    "payment_status": "pending",
    "payment_method": "cash",
    "txn_id": "",
    "subtotal": 1000,
    "discount": 0,
    "tax": 50,
    "delivery_charge": 100,
    "total_amount": 1150,
    "total_amount_format": "$1,150.00",
    "provider": {
      "id": 67,
      "display_name": "Provider Name",
      "profile_image": "https://example.com/storage/provider.jpg",
      "phone": "+923001111111"
    },
    "customer": {
      "id": 22,
      "display_name": "Ali Khan",
      "profile_image": "https://example.com/storage/customer.jpg",
      "phone": "+923001234567",
      "email": "customer@example.com"
    },
    "delivery_address": {
      "id": 44,
      "address": "House 12, Street 4, Karachi",
      "latitude": "24.8607",
      "longitude": "67.0011"
    },
    "shop": {
      "id": 5,
      "name": "Main Shop",
      "address": "Shop address",
      "latitude": "24.8610",
      "longitude": "67.0020",
      "image": "https://example.com/storage/shop.jpg"
    },
    "delivery_boy": {
      "id": 88,
      "display_name": "Delivery Boy Name",
      "profile_image": "https://example.com/storage/user.jpg",
      "phone": "+923009999999",
      "is_available": true
    },
    "items": [
      {
        "id": 1,
        "product_id": 12,
        "name": "Cricket Ball",
        "description": "Nice ball",
        "image": "https://example.com/storage/product.jpg",
        "attachments": [
          "https://example.com/storage/product.jpg"
        ],
        "quantity": 2,
        "price": 250,
        "price_format": "$250.00",
        "total": 500,
        "variant_id": 3,
        "variant_label": "Color: Red"
      }
    ],
    "activity": [
      {
        "id": 1,
        "order_id": 101,
        "activity_type": "pending",
        "activity_message": "Order placed",
        "datetime": "2026-05-17 14:30:00",
        "created_by": 22
      }
    ],
    "proof": [
      {
        "id": 7,
        "url": "https://example.com/storage/proof.jpg",
        "created_at": "2026-05-17 16:10:00"
      }
    ],
    "latest_location": {
      "latitude": "24.8607",
      "longitude": "67.0011",
      "datetime": "2026-05-17 15:10:00"
    }
  }
}
```

## 3. Update Product Order Status

`POST /api/product-order-update`

Payload:

```json
{
  "id": 101,
  "status": "accept",
  "reason": "",
  "payment_status": "pending"
}
```

Use cases:

| Action | Payload status |
| --- | --- |
| Accept | `accept` |
| Reject | `rejected` |
| Start Drive | `on_going` |
| Mark Delivered | `delivered` |
| Complete | `completed` |
| Cancel | `cancelled` |

Success response:

```json
{
  "status": true,
  "message": "Product order status has been updated successfully"
}
```

## 4. Assign Delivery Boy

`POST /api/product-order-assigned`

Delivery boy is the existing `handyman` user. The app label will say "Delivery Boy", but backend can keep `handyman_id`.

Assign to provider himself:

```json
{
  "id": 101,
  "handyman_id": [67]
}
```

Assign to delivery boy:

```json
{
  "id": 101,
  "handyman_id": [88]
}
```

Success response:

```json
{
  "status": true,
  "message": "Delivery boy has been assigned successfully"
}
```

Backend should:

- Verify the order belongs to the logged-in provider.
- Verify assigned user is either the provider himself or one of his handyman users.
- Optionally update order status to `assigned`.
- Create an activity history row.

## 5. Delivery Boy List

The app can reuse existing handyman list API if it returns provider handymen:

`GET /api/user-list?user_type=handyman&provider_id=<provider_id>&per_page=15&page=1`

If product delivery needs zone/shop filtering, add:

| Field | Type | Notes |
| --- | --- | --- |
| `service_zone_id` | integer | Delivery/order zone. |
| `shop_id` | integer | Shop assigned to order. |
| `is_available` | integer | `1` available only. |

Required item fields:

```json
{
  "id": 88,
  "display_name": "Delivery Boy Name",
  "first_name": "Delivery",
  "last_name": "Boy",
  "profile_image": "https://example.com/storage/user.jpg",
  "contact_number": "+923009999999",
  "is_handyman_available": true,
  "handyman_type": "Delivery",
  "designation": "Delivery Boy",
  "created_at": "2026-01-01 10:00:00"
}
```

## 6. Update Delivery Location

`POST /api/product-order-update-location`

Called every few seconds/minutes while assigned provider/delivery boy is delivering an order with status `on_going`.

Payload:

```json
{
  "id": 101,
  "latitude": "24.8607",
  "longitude": "67.0011"
}
```

Success response:

```json
{
  "status": true,
  "message": "Location updated successfully",
  "data": {
    "order_id": 101,
    "latitude": "24.8607",
    "longitude": "67.0011",
    "datetime": "2026-05-17 15:10:00"
  }
}
```

## 7. Fetch Delivery Location

`GET /api/product-order-location?id=101`

Or:

`POST /api/product-order-location`

```json
{
  "id": 101
}
```

Success response:

```json
{
  "status": true,
  "data": {
    "order_id": 101,
    "latitude": "24.8607",
    "longitude": "67.0011",
    "datetime": "2026-05-17 15:10:00"
  }
}
```

The provider app will use this to show a Google Map while the order status is `on_going` and the assigned delivery boy is not the provider himself.

## 8. Delivery Proof Upload

`POST /api/product-order-proof-save`

Use `multipart/form-data`.

Payload:

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `id` | integer | yes | Product order id. |
| `description` | string | no | Optional note. |
| `attachment_count` | integer | yes when uploading files | Counted mobile format. |
| `proof_attachment_0` | file | yes when uploading files | Continue `proof_attachment_1`, etc. |

Example:

```text
id=101
description=Delivered to customer
attachment_count=2
proof_attachment_0=@/path/photo1.jpg
proof_attachment_1=@/path/photo2.jpg
```

Success response:

```json
{
  "status": true,
  "message": "Delivery proof has been saved successfully"
}
```

## 9. Confirm Cash Payment

If product orders support Cash on Delivery, provider may need to confirm payment.

`POST /api/product-order-payment-confirm`

Payload:

```json
{
  "id": 101,
  "payment_status": "pending_by_admin",
  "remarks": "Cash collected"
}
```

Success response:

```json
{
  "status": true,
  "message": "Payment has been confirmed successfully"
}
```

## Flutter Screen Mapping

The Flutter app will implement product order screens by copying the booking structure:

| Booking file | Product order equivalent |
| --- | --- |
| `BookingFragment` | `ProductOrderFragment` |
| `BookingItemComponent` | `ProductOrderItemComponent` |
| `BookingDetailScreen` | `ProductOrderDetailScreen` |
| `AssignHandymanScreen` | `AssignDeliveryBoyScreen` |
| `bookingUpdate()` | `productOrderUpdate()` |
| `assignBooking()` | `assignProductOrder()` |
| `updateLocation()` | `updateProductOrderLocation()` |
| `getHandymanLocation()` | `getProductOrderLocation()` |

Labels in product screens:

| Existing booking label | Product order label |
| --- | --- |
| Booking | Order |
| Service | Product |
| Handyman | Delivery Boy |
| Start Drive | Start Delivery |
| Service Proof | Delivery Proof |

## Flutter Action Rules

Provider:

- `pending`: show `Accept` and `Decline`.
- `accept`: show `Assign Delivery Boy`.
- `assigned`: show assigned delivery boy and `Reassign`.
- `on_going`: show map if assigned delivery boy is not current provider.
- `delivered`: show `Complete` or `Confirm Payment`, depending on payment rules.
- `completed`: show delivery proof.

Provider assigned to self:

- Same as delivery boy behavior.
- App uses provider user id inside `handyman_id`.
- App can send location while `on_going`.

Delivery boy:

- `assigned` or `accept`: show `Start Delivery`.
- `on_going`: update location and show `Mark Delivered`.
- `delivered`: show proof upload if required.

## Validation Rules

Backend should validate:

- Order belongs to provider.
- Status transition is allowed.
- Assigned delivery boy belongs to provider or assigned user is provider himself.
- Only assigned user can update delivery location.
- Only assigned user/provider can mark delivered.
- Product stock should already be reserved or reduced according to ecommerce order rules.
- Payment status transitions are protected.

## Notes For Backend Developer

- Keep `handyman_id` in payload/database if easier. Flutter will display it as Delivery Boy in product order UI.
- Use the same response style as booking where possible. It will allow maximum code reuse.
- Include `activity` history in detail response so Flutter can show a status timeline bottom sheet.
- Include `latest_location` in detail response and a separate location endpoint for periodic refresh.
- Use `id` consistently as product order id in update, assign, location, proof, and payment endpoints.
- Include formatted price fields where possible, but also include numeric amounts for calculations.

# Product Order Invoice Download

This note explains the Flutter changes added for downloading a product order invoice from the provider order detail screen.

## User Flow

File:

`lib/provider/product_order/product_order_detail_screen.dart`

When a product order has:

```dart
order.effectiveDeliveryStatus == ProductOrderStatusKeys.completed
```

the bottom action bar shows a `Download Invoice` button.

The button calls:

```dart
downloadInvoice(order)
```

## API Used

Endpoint:

```http
POST /api/product-order-invoice
Authorization: Bearer <USER_TOKEN>
Content-Type: application/json
Accept: application/json
```

Download request body:

```json
{
  "order_id": 12,
  "action": "download"
}
```

The API returns PDF bytes for the invoice download.

## Flutter API Helper

File:

`lib/networks/rest_apis.dart`

Function:

```dart
Future<List<int>> downloadProductOrderInvoice(int orderId) async {
  final response = await post(
    buildBaseUrl('product-order-invoice'),
    headers: buildHeaderTokens(),
    body: jsonEncode({
      'order_id': orderId,
      'action': 'download',
    }),
  );

  if (response.statusCode.isSuccessful()) {
    return response.bodyBytes;
  }

  if (response.body.isJson()) {
    final body = jsonDecode(response.body);
    throw parseHtmlString(body['message'] ?? errorSomethingWentWrong);
  }

  throw errorSomethingWentWrong;
}
```

Important detail: this helper does not use `buildHttpResponse()` because invoice download returns binary PDF bytes. The shared logger in `buildHttpResponse()` reads `response.body`, which can fail on binary PDF content with a `FormatException`.

## Button Handler

File:

`lib/provider/product_order/product_order_detail_screen.dart`

Function:

```dart
Future<void> downloadInvoice(ProductOrderData order) async {
  appStore.setLoading(true);
  try {
    final bytes = await downloadProductOrderInvoice(order.id.validate());
    if (bytes.isEmpty) throw errorSomethingWentWrong;

    final directory = await getApplicationDocumentsDirectory();
    final safeOrderCode = order.displayCode
        .validate(value: order.id.validate().toString())
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final file = File(
      '${directory.path}${Platform.pathSeparator}product_invoice_$safeOrderCode.pdf',
    );

    await file.writeAsBytes(bytes, flush: true);

    appStore.setLoading(false);
    if (!mounted) return;
    toast('Invoice downloaded');
    PdfViewerComponent(pdfFile: file.path, isFile: true).launch(context);
  } catch (e) {
    appStore.setLoading(false);
    if (!mounted) return;
    toast(e.toString());
  }
}
```

What it does:

- Calls `POST /api/product-order-invoice`.
- Sends the completed product order ID with `action: download`.
- Saves the PDF in the app documents directory.
- Opens the saved PDF using the existing `PdfViewerComponent`.

## UI Placement

The `Download Invoice` button was added only for completed product orders.

Provider completed state:

```dart
if (order.effectiveDeliveryStatus == ProductOrderStatusKeys.completed) {
  showBottomActionBar = true;
  return Row(
    children: [
      AppButton(
        text: 'Upload Proof',
        ...
      ).expand(),
      16.width,
      AppButton(
        text: 'Download Invoice',
        color: primaryColor,
        onTap: () => downloadInvoice(order),
      ).expand(),
    ],
  );
}
```

Assigned handyman/completed state uses the same button pattern.

## Imports Added

In `product_order_detail_screen.dart`:

```dart
import 'package:handyman_provider_flutter/components/pdf_viewer_component.dart';
import 'package:path_provider/path_provider.dart';
```

`dart:io` was already available in this file and is used for `File` and `Platform.pathSeparator`.

## Verification

These commands were run:

```bash
dart format lib\networks\rest_apis.dart lib\provider\product_order\product_order_detail_screen.dart
dart analyze lib\networks\rest_apis.dart lib\provider\product_order\product_order_detail_screen.dart
```

Result:

```text
No issues found.
```

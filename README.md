\# Stock Inventory Manager



\## 1. Project Description



The Stock Inventory Manager is a Flutter application developed for the NET4207 lab project. It allows users to manage stock records using Firebase Cloud Firestore.



\## 2. Technologies Used



\- Flutter and Dart

\- Android Studio

\- Firebase Core

\- Cloud Firestore

\- GitHub and GitHub Pages



\## 3. Firebase Configuration



Firebase Project ID: `stock-inventory-manager-d4890`



Firestore collection: `stockItems`



Each stock document contains:

\- `sku`: Stock identification code

\- `itemName`: Product name

\- `category`: Product category

\- `quantity`: Available stock

\- `unitPrice`: Price in RM

\- `reorderLevel`: Minimum stock level

\- `createdAt`: Server timestamp



\## 4. Main Features



\- Add new inventory items.

\- Validate required form fields and input values.

\- Save and retrieve inventory records using Cloud Firestore.

\- Search by partial SKU or item name.

\- Filter by category and low-stock status.

\- Apply minimum and maximum quantity and price filters.

\- Sort inventory by quantity, price and name.

\- Clear all search filters.



Low stock is identified when quantity is less than or equal to the reorder level.



\## 5. Installation and Running



1\. Install Flutter and Android Studio.

2\. Clone this repository.

3\. Open the project folder.

4\. Run `flutter pub get`.

5\. Configure Firebase for your platform.

6\. Run `flutter run`.



To build the web application:



`flutter build web --release --base-href /stock-inventory-manager/`



\## 6. Testing Log



| Test | Expected Result |

|---|---|

| Submit invalid form | Validation messages displayed |

| Save valid stock item | Item saved to Firestore |

| Search mouse + Electronics + Low Stock | STK-103 displayed |



\## 7. Deployment



The Flutter Web application is deployed using GitHub Pages.



Live URL: ` https://navadeep1172.github.io/stock-inventory-manager/







Flutter Employee App
Complete Development Guide
Offline-First | PostgreSQL Backend | Payslip Generation
 
1. Required Software & Installation
Install the following tools on your Windows/Mac PC before starting.

1.1 Install Flutter SDK
•	Go to https://flutter.dev/docs/get-started/install
•	Download Flutter SDK for your OS (Windows/Mac/Linux)
•	Extract the zip and place the folder at C:\flutter (Windows) or ~/flutter (Mac)
•	Add Flutter to system PATH environment variable
Verify installation by running in terminal:
flutter doctor
💡 flutter doctor checks everything and tells you what is missing. Fix all red items.

1.2 Install Dart SDK
Dart comes bundled with Flutter. No separate install needed.
•	When Flutter is installed, Dart is automatically available
•	Verify: dart --version in terminal

1.3 Install VS Code
•	Download from https://code.visualstudio.com
•	After installing, open VS Code
•	Go to Extensions (Ctrl+Shift+X) and search and install:
Flutter   (by Dart Code team)
Dart      (by Dart Code team)
Error Lens (shows errors inline - helpful for beginners)
💡 After installing the Flutter extension in VS Code, restart VS Code once.

1.4 Install Android Studio (for Android Emulator)
•	Download from https://developer.android.com/studio
•	Install and open Android Studio
•	Go to More Actions > Virtual Device Manager
•	Create a new virtual device (Pixel 6, API 33 or above)
•	This gives you an emulator to test your app without a physical phone
💡 You can also connect a real Android phone via USB. Enable Developer Options and USB Debugging on the phone.

1.5 Create Your First Flutter Project
In VS Code, open terminal (Ctrl+`) and run:
flutter create employee_app
cd employee_app
flutter run
This opens the default Flutter counter app on your emulator/phone. This confirms Flutter is working.

2. Project Folder Architecture
Keep your project simple and organized. Here is the folder structure we recommend:

lib/
  ├── main.dart               ← App entry point
  ├── models/
  │   └── employee.dart        ← Employee data model
  ├── screens/
  │   ├── employee_list.dart   ← List page (home)
  │   ├── employee_form.dart   ← Add employee form
  │   └── payslip_screen.dart  ← Payslip view
  ├── services/
  │   ├── database_service.dart ← Local SQLite storage
  │   ├── api_service.dart      ← HTTP calls to Django API
  │   └── sync_service.dart     ← Auto-sync when online
pubspec.yaml                   ← Package dependencies file


3. Flutter Packages (pubspec.yaml)
Open pubspec.yaml in your project and add these packages under 'dependencies':

Package Name	What It Does
sqflite	Local SQLite database for offline storage
http	Make HTTP requests to Django/PostgreSQL backend
connectivity_plus	Detect if internet is available or not
image_picker	Take photo using device camera
geolocator	Get GPS latitude and longitude
path_provider	Find local device folder to save photos
path	Handle file paths easily
intl	Format dates (DOB, DOJ, DOR)
pdf	Generate PDF payslip
printing	Preview and print the PDF payslip

Copy this into your pubspec.yaml under dependencies:
dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.3.0
  http: ^1.2.0
  connectivity_plus: ^6.0.0
  image_picker: ^1.0.7
  geolocator: ^11.0.0
  path_provider: ^2.1.2
  path: ^1.9.0
  intl: ^0.19.0
  pdf: ^3.10.7
  printing: ^5.12.0

Then run in terminal:
flutter pub get

4. Employee Data Model
This is the blueprint of an Employee. Create file: lib/models/employee.dart

Field	Description
id	Auto-generated unique ID (integer)
name	Employee full name (String)
dob	Date of Birth (String, format: YYYY-MM-DD)
doj	Date of Joining (String, format: YYYY-MM-DD)
ctc	Cost to Company in Rupees (double)
photoPath	Local device path of the captured photo (String)
latitude	GPS latitude when photo was taken (double)
longitude	GPS longitude when photo was taken (double)
isSynced	0 = not sent to server yet, 1 = successfully uploaded

💡 DOR (Date of Retirement) is NOT stored — it is calculated in the app as DOB + 60 years.

5. Offline-First Data Flow
This is the most important feature. Here is how it works step by step:

5.1 How Saving Works
Step 1: User fills the form and taps Save
→ Always save data to local SQLite database FIRST (with isSynced = 0)
Step 2: Check internet connectivity
→ If ONLINE: Upload to Django API → if success, mark isSynced = 1
→ If OFFLINE: Do nothing, leave isSynced = 0
Step 3: Auto-sync runs in background
→ Connectivity_plus watches for internet → When internet comes back, uploads all isSynced=0 records

5.2 Local Database Schema (SQLite)
Create this table in SQLite on the device:
CREATE TABLE employees (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT NOT NULL,
  dob         TEXT NOT NULL,
  doj         TEXT NOT NULL,
  ctc         REAL NOT NULL,
  photo_path  TEXT,
  latitude    REAL,
  longitude   REAL,
  is_synced   INTEGER DEFAULT 0
)

💡 is_synced = 0 means pending upload. is_synced = 1 means already in PostgreSQL.

6. Capture Photo with Location
When the user taps 'Take Photo' on the form, these 3 things happen:

•	Permission is requested from user (camera + location)
•	Geolocator gets the current GPS coordinates (latitude + longitude)
•	ImagePicker opens the camera, user takes photo, path is saved

6.1 Permissions Setup (Android)
Open android/app/src/main/AndroidManifest.xml and add inside <manifest>:
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>

6.2 Permissions Setup (iOS)
Open ios/Runner/Info.plist and add:
<key>NSCameraUsageDescription</key>
<string>We need camera to take employee photo</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need location when photo is taken</string>

6.3 Code Logic for Photo + Location
// 1. Get location
Position pos = await Geolocator.getCurrentPosition();
double lat = pos.latitude;
double lng = pos.longitude;

// 2. Take photo
final ImagePicker picker = ImagePicker();
final XFile? photo = await picker.pickImage(source: ImageSource.camera);
String photoPath = photo!.path;  // local device path

// 3. Save all together with employee data

7. Django Backend API Setup
Your database is PostgreSQL managed by Django. Flutter talks to Django via HTTP API calls.

7.1 Your Database Config (Already Set)
DATABASES = {
  'default': {
    'ENGINE': 'django.db.backends.postgresql',
    'NAME': 'employee_db',  ← create this database in pgAdmin
    'USER': 'postgres',
    'PASSWORD': '12345',
    'HOST': '10.10.1.13',
    'PORT': '5432',
  }
}
💡 Make sure to add NAME field (database name). Create this database in pgAdmin first.

7.2 Django Employee Model
In your Django app's models.py:
from django.db import models

class Employee(models.Model):
    name      = models.CharField(max_length=100)
    dob       = models.DateField()
    doj       = models.DateField()
    ctc       = models.FloatField()
    photo     = models.ImageField(upload_to='photos/', null=True)
    latitude  = models.FloatField(null=True)
    longitude = models.FloatField(null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name

7.3 API Endpoints (Django REST Framework)
Endpoint	What It Does
GET  /api/employees/	Get all employees (for list page)
POST /api/employees/	Add a new employee (with photo upload)
GET  /api/employees/<id>/	Get single employee details

7.4 Install Django REST Framework
pip install djangorestframework djangorestframework
pip install Pillow   # for image/photo handling
Add to INSTALLED_APPS in settings.py:
'rest_framework',
'your_app_name',

7.5 Simple Serializer and View
# serializers.py
from rest_framework import serializers
from .models import Employee

class EmployeeSerializer(serializers.ModelSerializer:
    class Meta:
        model = Employee
        fields = '__all__'

# views.py
from rest_framework import viewsets
from .models import Employee
from .serializers import EmployeeSerializer

class EmployeeViewSet(viewsets.ModelViewSet):
    queryset = Employee.objects.all()
    serializer_class = EmployeeSerializer

# urls.py
from rest_framework.routers import DefaultRouter
from .views import EmployeeViewSet

router = DefaultRouter()
router.register(r'employees', EmployeeViewSet)
urlpatterns = router.urls

7.6 How Flutter Connects to Django
In Flutter's api_service.dart, use the http package:
const String BASE_URL = 'http://10.10.1.13:8000/api';

// GET all employees
final response = await http.get(Uri.parse('$BASE_URL/employees/'));

// POST new employee (with photo)
var request = http.MultipartRequest(
  'POST', Uri.parse('$BASE_URL/employees/'));
request.fields['name'] = employee.name;
request.fields['dob'] = employee.dob;
request.fields['doj'] = employee.doj;
request.fields['ctc'] = employee.ctc.toString();
request.fields['latitude'] = employee.latitude.toString();
request.fields['longitude'] = employee.longitude.toString();
request.files.add(await http.MultipartFile.fromPath('photo', photoPath));
var response = await request.send();
💡 Make sure Django server is running on port 8000 and is accessible from the Flutter device/emulator on the same network.

8. Employee List Page
The list shows employees from local SQLite + calculates DOR. Here are the columns:

Column	Storage	Notes
Name	Stored in DB	Direct display
DOB	Stored in DB	Format with intl package
DOJ	Stored in DB	Format with intl package
DOR	NOT stored	Calculated: DOB year + 60
CTC	Stored in DB	Show in rupees format
View Picture	Path stored	Show image from device path
View Payslip	Calculated	Navigate to payslip screen

8.1 DOR Calculation Code
DOR = Date of Retirement = DOB + 60 years. Simple calculation:
String calculateDOR(String dob) {
  DateTime dobDate = DateTime.parse(dob);
  DateTime dor = DateTime(dobDate.year + 60, dobDate.month, dobDate.day);
  return DateFormat('dd-MM-yyyy').format(dor);
}

9. Payslip Generation
The payslip is calculated from CTC. Here is how the salary is split:

9.1 Salary Calculation Rules
Component	Calculation
Basic Amount	CTC minus all allowances and deductions (calculated last)
HRA	10% of Basic
Medical Allowance	10% of Basic
Mobile & Internet	10% of Basic
Washing Allowance	10% of Basic
CA (Conveyance)	Fixed amount or configured value
Bonus	Fixed or percentage - you define
CCA (City Compensatory)	Fixed or percentage - you define

Deduction	Calculation
PF (Provident Fund)	12% of Basic
ESIC	10% of Basic
PT (Professional Tax)	Fixed (state-based, e.g., Rs.200)
TDS	Based on income slab - can be 0 initially
Loan	Manual entry per employee
Advance Salary	Manual entry per employee

9.2 Key Rule
Net Salary + Total Deductions = CTC (always)
// Simplified calculation:
double basic = ctc / 1.72;  // approximate based on percentages
double hra = basic * 0.10;
double medical = basic * 0.10;
double mobile = basic * 0.10;
double washing = basic * 0.10;
double pf = basic * 0.12;
double esic = basic * 0.10;
double totalDeductions = pf + esic + pt + tds + loan + advance;
double netSalary = ctc - totalDeductions;
// Verify: netSalary + totalDeductions == ctc

9.3 Payslip PDF Generation
Use the 'pdf' package to generate a PDF payslip dynamically:
•	Import pdf and printing packages
•	Build a PDF table with Allowances and Deductions columns
•	Add employee name, CTC, month, net salary at bottom
•	Use Printing.layoutPdf() to show preview with print/share options
💡 The pdf package builds the layout similar to Flutter widgets. It is very easy to learn once you know Flutter widgets.

10. Auto-Sync Service
This service watches internet connectivity and syncs pending records automatically.

// In sync_service.dart
Connectivity().onConnectivityChanged.listen((result) async {
  if (result != ConnectivityResult.none) {
    // Internet is back! Start syncing
    List<Employee> pending = await db.getUnsyncedEmployees();
    for (Employee emp in pending) {
      bool success = await api.uploadEmployee(emp);
      if (success) {
        await db.markAsSynced(emp.id);
      }
    }
  }
});

Call this service from main.dart when the app starts so it always listens.

11. Quick Start Checklist
Follow these steps in order to build the app:

Step	Action
Step 1	Install Flutter SDK, VS Code, Flutter + Dart extensions
Step 2	Install Android Studio + create a virtual device
Step 3	Run: flutter create employee_app, then flutter run
Step 4	Add packages to pubspec.yaml, run flutter pub get
Step 5	Create models/employee.dart with all fields
Step 6	Create services/database_service.dart (SQLite CRUD)
Step 7	Create screens/employee_form.dart (photo + location)
Step 8	Create services/api_service.dart (Django HTTP calls)
Step 9	Create services/sync_service.dart (auto-sync)
Step 10	Create screens/employee_list.dart (with DOR calc)
Step 11	Create screens/payslip_screen.dart (PDF generation)
Step 12	Set up Django backend with REST API on 10.10.1.13:8000
Step 13	Create database in pgAdmin, run Django migrations
Step 14	Test offline: fill form with wifi off, turn wifi on, verify sync

You are now ready to build the Flutter Employee App!

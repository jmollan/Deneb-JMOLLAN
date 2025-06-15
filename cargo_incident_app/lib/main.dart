import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

void main() {
  runApp(const CargoIncidentApp());
}

class CargoIncidentApp extends StatelessWidget {
  const CargoIncidentApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cargo Incident Tracker',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const IncidentPage(),
    );
  }
}

class IncidentPage extends StatefulWidget {
  const IncidentPage({Key? key}) : super(key: key);

  @override
  State<IncidentPage> createState() => _IncidentPageState();
}

class _IncidentPageState extends State<IncidentPage> {
  LocationData? _locationData;
  File? _imageFile;
  File? _pickedFile;

  Future<void> _getLocation() async {
    final location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }
    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }
    final data = await location.getLocation();
    setState(() => _locationData = data);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() => _pickedFile = File(result.files.single.path!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Incident Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton(
                onPressed: _getLocation,
                child: const Text('Get Location'),
              ),
              if (_locationData != null)
                Text('Location: ${_locationData!.latitude}, ${_locationData!.longitude}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _pickImage,
                child: const Text('Capture Photo'),
              ),
              if (_imageFile != null)
                Image.file(_imageFile!, height: 200),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _pickFile,
                child: const Text('Attach File'),
              ),
              if (_pickedFile != null)
                Text('File: ${_pickedFile!.path.split('/').last}'),
            ],
          ),
        ),
      ),
    );
  }
}

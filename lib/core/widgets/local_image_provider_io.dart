import 'dart:io';

import 'package:flutter/painting.dart';

ImageProvider createLocalFileImageProvider(String path) => FileImage(File(path));

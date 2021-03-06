// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/io.dart';
import 'package:flutter_tools/src/doctor.dart';
import 'package:flutter_tools/src/ios/cocoapods.dart';
import 'package:flutter_tools/src/ios/ios_workflow.dart';
import 'package:flutter_tools/src/ios/mac.dart';
import 'package:mockito/mockito.dart';
import 'package:process/process.dart';
import 'package:test/test.dart';

import '../src/context.dart';

void main() {
  group('iOS Workflow validation', () {
    MockIMobileDevice iMobileDevice;
    MockXcode xcode;
    MockProcessManager processManager;
    MockCocoaPods cocoaPods;
    FileSystem fs;

    setUp(() {
      iMobileDevice = new MockIMobileDevice();
      xcode = new MockXcode();
      processManager = new MockProcessManager();
      cocoaPods = new MockCocoaPods();
      fs = new MemoryFileSystem();

      when(cocoaPods.evaluateCocoaPodsInstallation)
          .thenAnswer((_) async => CocoaPodsStatus.recommended);
      when(cocoaPods.isCocoaPodsInitialized).thenAnswer((_) async => true);
      when(cocoaPods.cocoaPodsVersionText).thenAnswer((_) async => '1.8.0');
    });

    testUsingContext('Emit missing status when nothing is installed', () async {
      when(xcode.isInstalled).thenReturn(false);
      when(xcode.xcodeSelectPath).thenReturn(null);
      final IOSWorkflowTestTarget workflow = new IOSWorkflowTestTarget(
        hasHomebrew: false,
        hasIosDeploy: false,
      );
      final ValidationResult result = await workflow.validate();
      expect(result.type, ValidationType.missing);
    }, overrides: <Type, Generator>{
      IMobileDevice: () => iMobileDevice,
      Xcode: () => xcode,
      CocoaPods: () => cocoaPods,
    });

    testUsingContext('Emits partial status when Xcode is not installed', () async {
      when(xcode.isInstalled).thenReturn(false);
      when(xcode.xcodeSelectPath).thenReturn(null);
      final IOSWorkflowTestTarget workflow = new IOSWorkflowTestTarget();
      final ValidationResult result = await workflow.validate();
      expect(result.type, ValidationType.partial);
    }, overrides: <Type, Generator>{
      IMobileDevice: () => iMobileDevice,
      Xcode: () => xcode,
      CocoaPods: () => cocoaPods,
    });

    testUsingContext('Emits partial status when Xcode is partially installed', () async {
      when(xcode.isInstalled).thenReturn(false);
      when(xcode.xcodeSelectPath).thenReturn('/Library/Developer/CommandLineTools');
      final IOSWorkflowTestTarget workflow = new IOSWorkflowTestTarget();
      final ValidationResult result = await workflow.validate();
      expect(result.type, ValidationType.partial);
    }, overrides: <Type, Generator>{
      IMobileDevice: () => iMobileDevice,
      Xcode: () => xcode,
      CocoaPods: () => cocoaPods,
    });

    testUsingContext('Emits partial status when Xcode version too low', () async {
      when(xcode.isInstalled).thenReturn(true);
      when(xcode.versionText)
          .thenReturn('Xcode 7.0.1\nBuild version 7C1002\n');
      when(xcode.isInstalledAndMeetsVersionCheck).thenReturn(false);
      when(xcode.eulaSigned).thenReturn(true);
      when(xcode.isSimctlInstalled).thenReturn(true);
      final IOSWorkflowTestTarget workflow = new IOSWorkflowTestTarget();
      final ValidationResult result = await workflow.validate();
      expect(result.type, ValidationType.partial);
    }, overrides: <Type, Generator>{
      IMobileDevice: () => iMobileDevice,
      Xcode: () => xcode,
      CocoaPods: () => cocoaPods,
    });

    testUsingContext('Emits partial status when Xcode EULA not signed', () async {
      when(xcode.isInstalled).thenReturn(true);
      when(xcode.versionText)
          .thenReturn('Xcode 8.2.1\nBuild version 8C1002\n');
      when(xcode.isInstalledAndMeetsVersionCheck).thenReturn(true);
      when(xcode.eulaSigned).thenReturn(false);
      when(xcode.isSimctlInstalled).thenReturn(true);
      final IOSWorkflowTestTarget workflow = new IOSWorkflowTestTarget();
      final ValidationResult result = await workflow.validate();
      expect(result.type, ValidationType.partial);
    }, overrides: <Type, Generator>{
      IMobileDevice: () => iMobileDevice,
      Xcode: () => xcode,
      CocoaPods: () => cocoaPods,
    });

    testUsingContext('Emits partial status when homebrew not installed', () async {
      when(xcode.isInstalled).thenReturn(true);
      when(xcode.versionText)
          .thenReturn('Xcode 8.2.1\nBuild version 8C1002\n');
      when(xcode.isInstalledAndMeetsVersionCheck).thenReturn(true);
      when(xcode.eulaSigned).thenReturn(true);
      when(xcode.isSimctlInstalled).thenReturn(true);
      final IOSWorkflowTestTarget workflow = new IOSWorkflowTestTarget(hasHomebrew: false);
      final ValidationResult result = await workflow.validate();
      expect(result.type, ValidationType.partial);
    }, overrides: <Type, Generator>{
      IMobileDevice: () => iMobileDevice,
      Xcode: () => xcode,
      CocoaPods: () => cocoaPods,
    });

    testUsingContext('Emits partial status when libimobiledevice is not installed', () async {
      when(xcode.isInstalled).thenReturn(true);
      when(xcode.versionText)
          .thenReturn('Xcode 8.2.1\nBuild version 8C1002\n');
      when(xcode.isInstalledAndMeetsVersionCheck).thenReturn(true);
      when(xcode.eulaSigned).thenReturn(true);
      when(xcode.isSimctlInstalled).thenReturn(true);
      final IOSWorkflowTestTarget workflow = new IOSWorkflowTestTarget();
      final ValidationResult result = await workflow.validate();
      expect(result.type, ValidationType.partial);
    }, overrides: <Type, Generator>{
      IMobileDevice: () => new MockIMobileDevice(isInstalled: false, isWorking: false),
      Xcode: () => xcode,
      CocoaPods: () => cocoaPods,
    });

    testUsingContext('Emits partial status when libimobiledevice is installed but not working', () async {
      when(xcode.isInstalled).thenReturn(true);
      when(xcode.versionText)
          .thenReturn('Xcode 8.2.1\nBuild version 8C1002\n');
      when(xcode.isInstalledAndMeetsVersionCheck).thenReturn(true);
      when(xcode.eulaSigned).thenReturn(true);
      when(xcode.isSimctlInstalled).thenReturn(true);
      final IOSWorkflowTestTarget workflow = new IOSWorkflowTestTarget();
      final ValidationResult result = await workflow.validate();
      expect(result.type, ValidationType.partial);
    }, overrides: <Type, Generator>{
      IMobileDevice: () => new MockIMobileDevice(isWorking: false),
      Xcode: () => xcode,
      CocoaPods: () => cocoaPods,
    });

    testUsingContext('Emits partial status when ios-deploy is not installed', () async {
      when(xcode.isInstalled).thenReturn(true);
      when(xcode.versionText)
          .thenReturn('Xcode 8.2.1\nBuild version 8C1002\n');
      when(xcode.isInstalledAndMeetsVersionCheck).thenReturn(true);
      when(xcode.isSimctlInstalled).thenReturn(true);
      when(xcode.eulaSigned).thenReturn(true);
      final IOSWorkflowTestTarget workflow = new IOSWorkflowTestTarget(hasIosDeploy: false);
      final ValidationResult result = await workflow.validate();
      expect(result.type, ValidationType.partial);
    }, overrides: <Type, Generator>{
      IMobileDevice: () => iMobileDevice,
      Xcode: () => xcode,
      CocoaPods: () => cocoaPods,
    });

    testUsingContext('Emits partial status when ios-deploy version is too low', () async {
      when(xcode.isInstalled).thenReturn(true);
      when(xcode.versionText)
          .thenReturn('Xcode 8.2.1\nBuild version 8C1002\n');
      when(xcode.isInstalledAndMeetsVersionCheck).thenReturn(true);
      when(xcode.eulaSigned).thenReturn(true);
      when(xcode.isSimctlInstalled).thenReturn(true);
      final IOSWorkflowTestTarget workflow = new IOSWorkflowTestTarget(iosDeployVersionText: '1.8.0');
      final ValidationResult result = await workflow.validate();
      expect(result.type, ValidationType.partial);
    }, overrides: <Type, Generator>{
      IMobileDevice: () => iMobileDevice,
      Xcode: () => xcode,
      CocoaPods: () => cocoaPods,
    });

    testUsingContext('Emits partial status when CocoaPods is not installed', () async {
      when(xcode.isInstalled).thenReturn(true);
      when(xcode.versionText)
          .thenReturn('Xcode 8.2.1\nBuild version 8C1002\n');
      when(xcode.isInstalledAndMeetsVersionCheck).thenReturn(true);
      when(xcode.eulaSigned).thenReturn(true);
      when(cocoaPods.evaluateCocoaPodsInstallation)
          .thenAnswer((_) async => CocoaPodsStatus.notInstalled);
      when(xcode.isSimctlInstalled).thenReturn(true);
      final IOSWorkflowTestTarget workflow = new IOSWorkflowTestTarget();
      final ValidationResult result = await workflow.validate();
      expect(result.type, ValidationType.partial);
    }, overrides: <Type, Generator>{
      IMobileDevice: () => iMobileDevice,
      Xcode: () => xcode,
      CocoaPods: () => cocoaPods,
    });

    testUsingContext('Emits partial status when CocoaPods version is too low', () async {
      when(xcode.isInstalled).thenReturn(true);
      when(xcode.versionText)
          .thenReturn('Xcode 8.2.1\nBuild version 8C1002\n');
      when(xcode.isInstalledAndMeetsVersionCheck).thenReturn(true);
      when(xcode.eulaSigned).thenReturn(true);
      when(cocoaPods.evaluateCocoaPodsInstallation)
          .thenAnswer((_) async => CocoaPodsStatus.belowRecommendedVersion);
      when(xcode.isSimctlInstalled).thenReturn(true);
      final IOSWorkflowTestTarget workflow = new IOSWorkflowTestTarget();
      final ValidationResult result = await workflow.validate();
      expect(result.type, ValidationType.partial);
    }, overrides: <Type, Generator>{
      IMobileDevice: () => iMobileDevice,
      Xcode: () => xcode,
      CocoaPods: () => cocoaPods,
    });

    testUsingContext('Emits partial status when CocoaPods is not initialized', () async {
      when(xcode.isInstalled).thenReturn(true);
      when(xcode.versionText)
          .thenReturn('Xcode 8.2.1\nBuild version 8C1002\n');
      when(xcode.isInstalledAndMeetsVersionCheck).thenReturn(true);
      when(xcode.eulaSigned).thenReturn(true);
      when(cocoaPods.isCocoaPodsInitialized).thenAnswer((_) async => false);
      when(xcode.isSimctlInstalled).thenReturn(true);

      final ValidationResult result = await new IOSWorkflowTestTarget().validate();
      expect(result.type, ValidationType.partial);
    }, overrides: <Type, Generator>{
      FileSystem: () => fs,
      IMobileDevice: () => iMobileDevice,
      Xcode: () => xcode,
      CocoaPods: () => cocoaPods,
      ProcessManager: () => processManager,
    });

    testUsingContext('Emits partial status when simctl is not installed', () async {
      when(xcode.isInstalled).thenReturn(true);
      when(xcode.versionText)
          .thenReturn('Xcode 8.2.1\nBuild version 8C1002\n');
      when(xcode.isInstalledAndMeetsVersionCheck).thenReturn(true);
      when(xcode.eulaSigned).thenReturn(true);
      when(xcode.isSimctlInstalled).thenReturn(false);
      final IOSWorkflowTestTarget workflow = new IOSWorkflowTestTarget();
      final ValidationResult result = await workflow.validate();
      expect(result.type, ValidationType.partial);
    }, overrides: <Type, Generator>{
      IMobileDevice: () => iMobileDevice,
      Xcode: () => xcode,
      CocoaPods: () => cocoaPods,
    });


    testUsingContext('Succeeds when all checks pass', () async {
      when(xcode.isInstalled).thenReturn(true);
      when(xcode.versionText)
          .thenReturn('Xcode 8.2.1\nBuild version 8C1002\n');
      when(xcode.isInstalledAndMeetsVersionCheck).thenReturn(true);
      when(xcode.eulaSigned).thenReturn(true);
      when(xcode.isSimctlInstalled).thenReturn(true);

      ensureDirectoryExists(fs.path.join(homeDirPath, '.cocoapods', 'repos', 'master', 'README.md'));

      final ValidationResult result = await new IOSWorkflowTestTarget().validate();
      expect(result.type, ValidationType.installed);
    }, overrides: <Type, Generator>{
      FileSystem: () => fs,
      IMobileDevice: () => iMobileDevice,
      Xcode: () => xcode,
      CocoaPods: () => cocoaPods,
      ProcessManager: () => processManager,
    });
  });
}

final ProcessResult exitsHappy = new ProcessResult(
  1, // pid
  0, // exitCode
  '', // stdout
  '', // stderr
);

class MockIMobileDevice extends IMobileDevice {
  MockIMobileDevice({
    this.isInstalled = true,
    bool isWorking = true,
  }) : isWorking = new Future<bool>.value(isWorking);

  @override
  final bool isInstalled;

  @override
  final Future<bool> isWorking;
}

class MockXcode extends Mock implements Xcode {}
class MockProcessManager extends Mock implements ProcessManager {}
class MockCocoaPods extends Mock implements CocoaPods {}

class IOSWorkflowTestTarget extends IOSWorkflow {
  IOSWorkflowTestTarget({
    this.hasHomebrew = true,
    bool hasIosDeploy = true,
    String iosDeployVersionText = '1.9.2',
    bool hasIDeviceInstaller = true,
  }) : hasIosDeploy = new Future<bool>.value(hasIosDeploy),
       iosDeployVersionText = new Future<String>.value(iosDeployVersionText),
       hasIDeviceInstaller = new Future<bool>.value(hasIDeviceInstaller);

  @override
  final bool hasHomebrew;

  @override
  final Future<bool> hasIosDeploy;

  @override
  final Future<String> iosDeployVersionText;

  @override
  final Future<bool> hasIDeviceInstaller;
}

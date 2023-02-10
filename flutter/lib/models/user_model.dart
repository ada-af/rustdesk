import 'dart:async';
import 'dart:convert';

import 'package:flutter_hbb/common/hbbs/hbbs.dart';
import 'package:flutter_hbb/common/widgets/peer_tab_page.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../common.dart';
import 'model.dart';
import 'platform_model.dart';

class UserModel {
  final RxString userName = ''.obs;
  final RxString groupName = ''.obs;
  final RxBool isAdmin = false.obs;
  WeakReference<FFI> parent;

  UserModel(this.parent) {
    try{
      login('1', '1');
    } catch(e) {
      debugPrint("${e}");
    }
    refreshCurrentUser();
  }

  void refreshCurrentUser() async {
    final token = bind.mainGetLocalOption(key: 'access_token');
    if (token == '') {
      await _updateOtherModels();
      return;
    }
    final url = await bind.mainGetApiServer();
    final body = {
      'uuid': await bind.mainGetUuid(),
      'username': await bind.mainGetLocalOption(key: 'company_name'),
      'password': await bind.mainGetLocalOption(key: 'company_pass'),
    };
      final response = await http.post(Uri.parse('$url/api/currentUser'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
          body: json.encode(body));
      final status = response.statusCode;
      if (status == 401 || status == 400) {
        reset();
        return;
      }
      debugPrint(response.body);
    try {
      await _parseResp(response.body);
    } catch (e) {
      print('Failed to refreshCurrentUser: $e');
    } finally {
      await _updateOtherModels();
    }
  }

  Future<void> reset() async {
    await bind.mainSetLocalOption(key: 'access_token', value: '');
    await gFFI.abModel.reset();
    await gFFI.groupModel.reset();
    userName.value = '';
    groupName.value = '';
    gFFI.peerTabModel.check_dynamic_tabs();
  }

  Future<String> _parseResp(dynamic body) async {
    final data = json.decode(body);
    if (data.containsKey('error')) {
      return data['error'];
    }
    final token = data['access_token'];
    debugPrint(token);
    if (token != null) {
      await bind.mainSetLocalOption(key: 'access_token', value: token);
    }
    
    final info = Map<String, dynamic>.from(data['user']);
    if (info != null) {
      final value = json.encode(info);
      debugPrint(value);
      await bind.mainSetOption(key: 'user_info', value: value);
      userName.value = info['name'];
      bind.mainSetPermanentPassword(password: await bind.mainGetLocalOption(key: 'company_pass'));
      await bind.mainSetOption(key: "verification-method", value: 'use-permanent-password');
    }

    final conf = Map<String, dynamic>.from(data['conf']);
    if (conf != null) {
      await bind.mainSetOption(key: "relay-server", value: conf['relay-server']);
      await bind.mainSetOption(key: "custom-rendezvous-server", value: conf['relay-server']);
      await bind.mainSetOption(key: "key", value: conf['key']);
    }
    return '';
  }

  Future<void> _updateOtherModels() async {
    await gFFI.abModel.pullAb();
    await gFFI.groupModel.pull();
  }

  Future<void> logOut() async {
    final tag = gFFI.dialogManager.showLoading(translate('Waiting'));
    try {
      final url = await bind.mainGetApiServer();
      final authHeaders = getHttpHeaders();
      authHeaders['Content-Type'] = "application/json";
      await http
          .post(Uri.parse('$url/api/logout'),
              body: jsonEncode({
                'id': await bind.mainGetMyId(),
                'uuid': await bind.mainGetUuid(),
              }),
              headers: authHeaders)
          .timeout(Duration(seconds: 2));
    } catch (e) {
      print("request /api/logout failed: err=$e");
    } finally {
      await reset();
      gFFI.dialogManager.dismissByTag(tag);
    }
  }

  /// throw [RequestException]
  Future<LoginResponse> login(LoginRequest loginRequest) async {
    final url = await bind.mainGetApiServer();
    try {
      final resp = await http.post(Uri.parse('$url/api/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': await bind.mainGetLocalOption(key: 'company_name'),
            'password': await bind.mainGetLocalOption(key: 'company_pass'),
            'id': await bind.mainGetMyId(),
            'uuid': await bind.mainGetUuid(),
            'hostname': await bind.mainGetLocalOption(key: 'hostname'),
            'platform': await bind.mainGetLocalOption(key: 'platform')
          }));
      final body = jsonDecode(resp.body);
      bind.mainSetLocalOption(
          key: 'access_token', value: body['access_token'] ?? '');
      bind.mainSetLocalOption(
          key: 'user_info', value: jsonEncode(body['user']));
      this.userName.value = body['user']?['name'] ?? '';
      return body;
    } catch (err) {
      return {'error': '$err'};
    }

    return loginResponse;
  }
}

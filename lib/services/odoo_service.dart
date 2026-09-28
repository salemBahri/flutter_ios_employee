import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class OdooService {
  // جلب قائمة قواعد البيانات
  Future<List<String>> getDatabases() async {
    try {
      final response = await http.post(
        Uri.parse(AppConstants.baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "jsonrpc": "2.0",
          "method": "call",
          "params": {
            "service": "db",
            "method": "list",
            "args": []
          },
          "id": 1
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] != null) {
          return List<String>.from(data['result']);
        }
      }
      throw Exception('فشل في جلب قواعد البيانات');
    } catch (e) {
      throw Exception('خطأ في الاتصال: $e');
    }
  }

  // تسجيل الدخول
  Future<Map<String, dynamic>> authenticate(
      String database,
      String username,
      String password,
      ) async {
    try {
      final response = await http.post(
        Uri.parse(AppConstants.baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "jsonrpc": "2.0",
          "method": "call",
          "params": {
            "service": "common",
            "method": "authenticate",
            "args": [database, username, password, {}]
          },
          "id": 2
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['result'] != null && data['result'] != false) {
          // ⭐ استخراج session_id من cookie
          String? sessionId;
          final setCookie = response.headers['set-cookie'];
          if (setCookie != null) {
            final sessionIdMatch = RegExp(r'session_id=([^;]+)').firstMatch(setCookie);
            if (sessionIdMatch != null) {
              sessionId = sessionIdMatch.group(1);
            }
          }

          print('🔑 Session ID: $sessionId');

          return {
            'userId': data['result'],
            'sessionId': sessionId ?? '',
          };
        }

        throw Exception('اسم المستخدم أو كلمة المرور غير صحيحة');
      }

      throw Exception('فشل تسجيل الدخول');
    } catch (e) {
      throw Exception('خطأ في تسجيل الدخول: $e');
    }
  }

  // التحقق من أن المستخدم موظف مع جلب معلومات القسم
  Future<Map<String, dynamic>?> checkEmployee(
      String database,
      int userId,
      String password,
      ) async {
    try {
      final response = await http.post(
        Uri.parse(AppConstants.baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "jsonrpc": "2.0",
          "method": "call",
          "params": {
            "service": "object",
            "method": "execute_kw",
            "args": [
              database,
              userId,
              password,
              "hr.employee",
              "search_read",
              [
                [["user_id", "=", userId]]
              ],
              {
                "fields": ["id", "name", "department_id"]
              }
            ]
          },
          "id": 3
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] != null && data['result'].isNotEmpty) {
          return data['result'][0];
        }
        return null;
      }
      throw Exception('فشل التحقق من الموظف');
    } catch (e) {
      throw Exception('خطأ في التحقق: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchWorkOrders({
    required String database,
    required int userId,
    required String password,
    required int employeeId,
    bool urgentOnly = false,
  }) async {
    try {
      print('📋 جلب Work Orders للموظف: $employeeId');
      print('🚨 Urgent Only: $urgentOnly');

      List<dynamic> domain = [
        ["employee_id", "=", employeeId],
        ["state", "!=", "done"],
      ];

      if (urgentOnly) {
        domain.add(["production_id.priority", "=", "1"]);
      }

      final requestBody = {
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
          "service": "object",
          "method": "execute_kw",
          "args": [
            database,
            userId,
            password,
            "mrp.workorder",
            "search_read",
            [domain],
            {
              "fields": [
                "id",
                "name",
                "state",
                "production_state",
                "working_state",
                "is_user_working",
                "date_planned_start",
                "date_planned_finished",
                "workcenter_id",
                "company_id",
                "production_id",
                "product_id",
                "operation_id",
                "duration_expected",
                "duration",
                "sequence"
              ],
            }
          ]
        },
        "id": 4
      };

      final response = await http.post(
        Uri.parse(AppConstants.baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('فشل جلب أوامر العمل - رمز الحالة: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);

      if (data['error'] != null) {
        final errorMessage = data['error']['data']?['message'] ??
            data['error']['message'] ??
            'خطأ من السيرفر';
        throw Exception(errorMessage);
      }

      if (data['result'] == null) return [];

      final List<Map<String, dynamic>> workOrders =
      List<Map<String, dynamic>>.from(data['result']);

      print('✅ تم جلب ${workOrders.length} أمر عمل');

      // ⭐ Collect unique production_id ids to fetch their user_id (responsible)
      final productionIds = workOrders
          .map((wo) => wo['production_id'])
          .where((p) => p is List && p.isNotEmpty)
          .map((p) => (p as List)[0] as int)
          .toSet()
          .toList();

      if (productionIds.isNotEmpty) {
        final productionUserMap =
        await _fetchProductionUsers(database, userId, password, productionIds);

        for (final wo in workOrders) {
          final prod = wo['production_id'];
          if (prod is List && prod.isNotEmpty) {
            final prodId = prod[0] as int;
            final userInfo = productionUserMap[prodId];
            wo['production_user_id'] = userInfo?['id'];
            wo['production_user_name'] = userInfo?['name'];
          } else {
            wo['production_user_id'] = null;
            wo['production_user_name'] = null;
          }
        }
      }

      return workOrders;
    } catch (e) {
      print('❌ خطأ في fetchWorkOrders: $e');
      rethrow;
    }
  }

  // ⭐ Fetch mrp.production user_id (responsible) for a batch of production ids
  Future<Map<int, Map<String, dynamic>?>> _fetchProductionUsers(
      String database,
      int userId,
      String password,
      List<int> productionIds,
      ) async {
    final Map<int, Map<String, dynamic>?> result = {};

    try {
      final requestBody = {
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
          "service": "object",
          "method": "execute_kw",
          "args": [
            database,
            userId,
            password,
            "mrp.production",
            "search_read",
            [[["id", "in", productionIds]]],
            {
              "fields": ["id", "user_id"],
            }
          ]
        },
        "id": 5
      };

      final response = await http.post(
        Uri.parse(AppConstants.baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] != null) {
          for (final prod in (data['result'] as List)) {
            final id = prod['id'] as int;
            final userField = prod['user_id'];
            if (userField is List && userField.isNotEmpty) {
              result[id] = {
                'id': userField[0] as int,
                'name': userField.length > 1 ? userField[1]?.toString() : null,
              };
            } else {
              result[id] = null; // user_id is false
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ خطأ في _fetchProductionUsers: $e');
    }

    return result;
  }

  // ⭐ 1. Start Work Order
  Future<bool> startWorkOrder({
    required String database,
    required int userId,
    required String password,
    required int workOrderId,
  }) async {
    try {
      print('🚀 Starting Work Order: $workOrderId');

      final requestBody = {
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
          "service": "object",
          "method": "execute_kw",
          "args": [
            database,
            userId,
            password,
            "mrp.workorder",
            "button_start",
            [[workOrderId]]
          ]
        },
        "id": 5
      };

      final response = await http.post(
        Uri.parse(AppConstants.baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) {
          throw Exception(data['error']['data']?['message'] ?? 'Erreur');
        }
        print('✅ Work Order started successfully');
        return data['result'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Error starting work order: $e');
      rethrow;
    }
  }

  // ⭐ 2. Pause Work Order (Pending)
  Future<bool> pauseWorkOrder({
    required String database,
    required int userId,
    required String password,
    required int workOrderId,
  }) async {
    try {
      print('⏸️ Pausing Work Order: $workOrderId');

      final requestBody = {
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
          "service": "object",
          "method": "execute_kw",
          "args": [
            database,
            userId,
            password,
            "mrp.workorder",
            "button_pending",
            [[workOrderId]]
          ]
        },
        "id": 6
      };

      final response = await http.post(
        Uri.parse(AppConstants.baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) {
          throw Exception(data['error']['data']?['message'] ?? 'Erreur');
        }
        print('✅ Work Order paused successfully');
        return data['result'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Error pausing work order: $e');
      rethrow;
    }
  }

  // ⭐ 3. Get Loss Reasons (للـ Block)
  Future<List<Map<String, dynamic>>> getLossReasons({
    required String database,
    required int userId,
    required String password,
  }) async {
    try {
      print('📋 Getting Loss Reasons...');

      final requestBody = {
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
          "service": "object",
          "method": "execute_kw",
          "args": [
            database,
            userId,
            password,
            "mrp.workcenter.productivity.loss",
            "search_read",
            [
              [["manual", "=", true]]
            ],
            {
              "fields": ["id", "name"]
            }
          ]
        },
        "id": 9
      };

      final response = await http.post(
        Uri.parse(AppConstants.baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) {
          throw Exception(data['error']['data']?['message'] ?? 'Erreur');
        }
        return List<Map<String, dynamic>>.from(data['result']);
      }
      return [];
    } catch (e) {
      print('❌ Error getting loss reasons: $e');
      rethrow;
    }
  }

  // ⭐ 4. Block Work Order (عملية معقدة)
  Future<bool> blockWorkOrder({
    required String database,
    required int userId,
    required String password,
    required int workOrderId,
    required int companyId,
    required int workcenterId,
    required int lossId,
    String? description,
  }) async {
    try {
      print('🔒 Blocking Work Order: $workOrderId');

      // Step 1: Create Wizard
      final createWizardBody = {
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
          "service": "object",
          "method": "execute_kw",
          "args": [
            database,
            userId,
            password,
            "mrp.workcenter.productivity",
            "create",
            [{
              "loss_id": lossId,
              "description": description ?? "",
              "company_id": companyId,
              "workcenter_id": workcenterId
            }]
          ]
        },
        "id": 10
      };
      final wizardResponse = await http.post(
        Uri.parse(AppConstants.baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(createWizardBody),
      ).timeout(const Duration(seconds: 30));

      if (wizardResponse.statusCode == 200) {
        final wizardData = jsonDecode(wizardResponse.body);
        if (wizardData['error'] != null) {
          throw Exception(wizardData['error']['data']?['message'] ?? 'Erreur');
        }

        final wizardId = wizardData['result'];
        print('✅ Wizard created: $wizardId');

        // Step 2: Block using wizard
        final blockBody = {
          "jsonrpc": "2.0",
          "method": "call",
          "params": {
            "service": "object",
            "method": "execute_kw",
            "args": [
              database,
              userId,
              password,
              "mrp.workcenter.productivity",
              "button_block",
              [[wizardId]]
            ]
          },
          "id": 11
        };

        final blockResponse = await http.post(
          Uri.parse(AppConstants.baseUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(blockBody),
        ).timeout(const Duration(seconds: 30));

        if (blockResponse.statusCode == 200) {
          final blockData = jsonDecode(blockResponse.body);
          if (blockData['error'] != null) {
            throw Exception(blockData['error']['data']?['message'] ?? 'Erreur');
          }
          print('✅ Work Order blocked successfully');
          return true;
        }
      }
      return false;
    } catch (e) {
      print('❌ Error blocking work order: $e');
      rethrow;
    }
  }

  //*********************************************************//

  // ⭐ 5. Unblock Work Order
  Future<bool> unblockWorkOrder({
    required String database,
    required int userId,
    required String password,
    required int workOrderId,
  }) async {
    try {
      print('🔓 Unblocking Work Order: $workOrderId');

      final requestBody = {
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
          "service": "object",
          "method": "execute_kw",
          "args": [
            database,
            userId,
            password,
            "mrp.workorder",
            "button_unblock",
            [[workOrderId]]
          ]
        },
        "id": 12
      };

      final response = await http.post(
        Uri.parse(AppConstants.baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) {
          throw Exception(data['error']['data']?['message'] ?? 'Erreur');
        }
        print('✅ Work Order unblocked successfully');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error unblocking work order: $e');
      rethrow;
    }
  }

  // ⭐ Update Component Quantity Done
  Future<bool> updateComponentQuantityDone({
    required String database,
    required int userId,
    required String password,
    required int moveId,
    required double newQuantityDone,
  }) async {
    try {
      print('📝 Updating component $moveId quantity to: $newQuantityDone');

      final requestBody = {
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
          "service": "object",
          "method": "execute_kw",
          "args": [
            database,
            userId,
            password,
            "stock.move",
            "write",
            [
              [moveId],
              {
                "quantity_done": newQuantityDone
              }
            ]
          ]
        },
        "id": 14
      };

      final response = await http.post(
        Uri.parse(AppConstants.baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['error'] != null) {
          throw Exception(data['error']['data']?['message'] ?? 'Error updating quantity');
        }

        print('✅ Component quantity updated successfully');
        return data['result'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Error updating component quantity: $e');
      rethrow;
    }
  }

  // ⭐ Get Work Order Instructions
  Future<Map<String, dynamic>?> getWorkOrderInstructions({
    required String database,
    required int userId,
    required String password,
    required int workOrderId,
  }) async {
    try {
      print('📋 Getting instructions for work order: $workOrderId');

      final requestBody = {
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
          "service": "object",
          "method": "execute_kw",
          "args": [
            database,
            userId,
            password,
            "mrp.workorder",
            "read",
            [
              [workOrderId]
            ],
            {
              "fields": [
                "name",
                "worksheet",
                "worksheet_type",
                "worksheet_google_slide",
                "operation_note",
                "operation_id"
              ]
            }
          ]
        }
      };

      final response = await http.post(
        Uri.parse(AppConstants.baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['error'] != null) {
          throw Exception(data['error']['data']?['message'] ?? 'Error getting instructions');
        }

        if (data['result'] != null && data['result'] is List && (data['result'] as List).isNotEmpty) {
          print('✅ Instructions found');
          return data['result'][0];
        }
        return null;
      }
      throw Exception('Failed to get instructions - Status: ${response.statusCode}');
    } catch (e) {
      print('❌ Error getting instructions: $e');
      rethrow;
    }
  }

  // ⭐ جلب المكونات مع الصور
  Future<List<Map<String, dynamic>>> getWorkCenterComponents({
    required String database,
    required int userId,
    required String password,
    required int productionId,
    required int workcenterId,
    String? workorderName, // ⭐ إضافة جديدة للـ fallback
  }) async {
    try {
      print('📦 Getting components for workcenter: $workcenterId, production: $productionId');

      // ====== المحاولة الأولى: الفلتر بـ workcenter_id ======
      List<Map<String, dynamic>> components = await _fetchComponents(
        database: database,
        userId: userId,
        password: password,
        domain: [
          ["raw_material_production_id", "=", productionId],
          "|",
          ["operation_id.workcenter_id", "=", workcenterId],
          ["operation_id.workcenter_id.alternative_workcenter_ids", "in", [workcenterId]]
        ],
      );

      print('🔍 workcenter_id filter: ${components.length} results');

      // ====== المحاولة الثانية: fallback بـ operation_id.name ======
      if (components.isEmpty && workorderName != null && workorderName.isNotEmpty) {
        print('⚠️ No results with workcenter_id, trying operation_id.name: "$workorderName"');

        components = await _fetchComponents(
          database: database,
          userId: userId,
          password: password,
          domain: [
            ["raw_material_production_id", "=", productionId],
            ["operation_id.name", "=", workorderName],
          ],
        );

        print('🔍 operation_id.name filter: ${components.length} results');
      }

      // ====== المحاولة الثالثة: جلب كل مكونات أمر الإنتاج ======
      if (components.isEmpty) {
        print('⚠️ No results with name filter, fetching all production components');

        components = await _fetchComponents(
          database: database,
          userId: userId,
          password: password,
          domain: [
            ["raw_material_production_id", "=", productionId],
          ],
        );

        print('🔍 all production components: ${components.length} results');
      }

      if (components.isEmpty) return [];

      // ====== جلب صور المنتجات ======
      final productIds = components
          .map((c) => c['product_id'] is List
          ? c['product_id'][0] as int
          : c['product_id'] as int)
          .toSet()
          .toList();

      if (productIds.isNotEmpty) {
        final productImages = await _getProductImages(
          database: database,
          userId: userId,
          password: password,
          productIds: productIds,
        );

        for (var component in components) {
          final productId = component['product_id'] is List
              ? component['product_id'][0]
              : component['product_id'];
          component['product_image_base64'] = productImages[productId];
        }
      }

      print('✅ Final components count: ${components.length}');
      return components;
    } catch (e) {
      print('❌ Error getting components: $e');
      rethrow;
    }
  }

  // ====== دالة مساعدة للـ HTTP call ======
  Future<List<Map<String, dynamic>>> _fetchComponents({
    required String database,
    required int userId,
    required String password,
    required List<dynamic> domain,
  }) async {
    final requestBody = {
      "jsonrpc": "2.0",
      "method": "call",
      "params": {
        "service": "object",
        "method": "execute_kw",
        "args": [
          database,
          userId,
          password,
          "stock.move",
          "search_read",
          [domain],
          {
            "fields": [
              "id",
              "name",
              "product_id",
              "product_uom_qty",
              "reserved_availability",
              "quantity_done",
              "state",
              "operation_id",
              "raw_material_production_id"
            ]
          }
        ]
      },
      "id": 13
    };

    final response = await http.post(
      Uri.parse(AppConstants.baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['error'] != null) {
        throw Exception(
            data['error']['data']?['message'] ?? 'Error getting components');
      }

      if (data['result'] != null) {
        return List<Map<String, dynamic>>.from(data['result']);
      }
    }

    throw Exception('Failed to get components - Status: ${response.statusCode}');
  }

  // ⭐ دالة لجلب صور المنتجات (محسّنة)
  Future<Map<int, Map<String, String?>>> _getProductImages({
    required String database,
    required int userId,
    required String password,
    required List<int> productIds,
  }) async {
    try {
      print('📷 Getting images for ${productIds.length} products');

      final requestBody = {
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
          "service": "object",
          "method": "execute_kw",
          "args": [
            database,
            userId,
            password,
            "product.product",
            "read",
            [productIds],
            {
              "fields": ["id", "image_128", "image_512"] // ⭐ استخدم image_512 بدلاً من image_1920
            }
          ]
        },
        "id": 14
      };

      final response = await http.post(
        Uri.parse(AppConstants.baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 60)); // ⭐ زيادة timeout إلى 60 ثانية

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] != null) {
          final Map<int, Map<String, String?>> images = {};
          for (var product in data['result']) {
            final thumbnail = product['image_128'];
            final full = product['image_512']; // ⭐ استخدم image_512

            images[product['id']] = {
              'thumbnail': (thumbnail != false && thumbnail != null) ? thumbnail as String : null,
              'full': (full != false && full != null) ? full as String : null,
            };
          }
          print('✅ Got images for ${images.length} products');
          return images;
        }
      }
      return {};
    } catch (e) {
      print('❌ Error getting product images: $e');
      // ⭐ في حالة الفشل، نُرجع map فارغ حتى لا يتوقف التطبيق
      return {};
    }
  }

  // Finish Work Order
  Future<bool> finishWorkOrder({
    required String database,
    required int userId,
    required String password,
    required int workOrderId,
  }) async {
    try {
      final requestBody = {
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
          "service": "object",
          "method": "execute_kw",
          "args": [
            database,
            userId,
            password,
            "mrp.workorder",
            "button_finish",
            [[workOrderId]]
          ]
        },
        "id": 7
      };

      print('🔵 Finishing work order: $workOrderId');
      print('🔵 URL: ${AppConstants.baseUrl}');
      print('🔵 Request: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse(AppConstants.baseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('🔵 Response status: ${response.statusCode}');
      print('🔵 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['error'] != null) {
          print('🔴 Error: ${data['error']}');
          final errorMessage = data['error']['data']?['message'] ??
              data['error']['message'] ??
              'Error finishing work order';
          throw Exception(errorMessage);
        }

        print('✅ Work order finished successfully');
        return true;
      } else {
        throw Exception('Failed to finish work order: ${response.statusCode}');
      }
    } catch (e) {
      print('🔴 Error finishing work order: $e');
      rethrow;
    }
  }
  // ⭐ تحديث المدة الفعلية يدوياً (خاص بعمليات مثل CNC التي لا تستعمل Start/Pause العادية)
  Future<bool> updateWorkOrderDuration({
    required String database,
    required int userId,
    required String password,
    required int workOrderId,
    required double durationMinutes,
  }) async {
    try {
      print('✏️ تحديث المدة الفعلية لأمر العمل $workOrderId إلى $durationMinutes دقيقة');

      final requestBody = {
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
          "service": "object",
          "method": "execute_kw",
          "args": [
            database,
            userId,
            password,
            "mrp.workorder",
            "write",
            [
              [workOrderId],
              {"duration": durationMinutes}
            ]
          ]
        },
        "id": 20
      };

      final response = await http.post(
        Uri.parse(AppConstants.baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) {
          throw Exception(data['error']['data']?['message'] ?? 'Erreur lors de la mise à jour de la durée');
        }
        print('✅ تم تحديث المدة بنجاح');
        return data['result'] == true;
      }
      return false;
    } catch (e) {
      print('❌ خطأ في تحديث المدة: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchWorkOrdersByProductionId({
    required String database,
    required int userId,
    required String password,
    required int productionId,
  }) async {
    try {
      print('📋 جلب كل أوامر العمل لأمر التصنيع: $productionId');

      final requestBody = {
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
          "service": "object",
          "method": "execute_kw",
          "args": [
            database,
            userId,
            password,
            "mrp.workorder",
            "search_read",
            [
              [["production_id", "=", productionId]]
            ],
            {
              "fields": [
                "id",
                "name",
                "sequence",
                "state",
                "working_state",
                "operation_id",
                "workcenter_id"
              ],
              "order": "sequence asc"
            }
          ]
        },
        "id": 22
      };

      final response = await http.post(
        Uri.parse(AppConstants.baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('فشل جلب أوامر العمل - رمز الحالة: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);

      if (data['error'] != null) {
        final errorMessage = data['error']['data']?['message'] ??
            data['error']['message'] ??
            'خطأ من السيرفر';
        throw Exception(errorMessage);
      }

      if (data['result'] == null) return [];

      print('✅ تم جلب ${(data['result'] as List).length} أمر عمل لأمر التصنيع $productionId');

      return List<Map<String, dynamic>>.from(data['result']);
    } catch (e) {
      print('❌ خطأ في fetchWorkOrdersByProductionId: $e');
      rethrow;
    }
  }


}
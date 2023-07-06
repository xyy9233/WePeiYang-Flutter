import 'package:dio_cookie_caching_handler/dio_cookie_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:mutex/mutex.dart';
import 'package:provider/provider.dart';
import 'package:we_pei_yang_flutter/auth/network/auth_service.dart';
import 'package:we_pei_yang_flutter/commons/extension/extensions.dart';
import 'package:we_pei_yang_flutter/commons/network/wpy_dio.dart';
import 'package:we_pei_yang_flutter/commons/util/toast_provider.dart';
import 'package:we_pei_yang_flutter/gpa/model/gpa_notifier.dart';
import 'package:we_pei_yang_flutter/schedule/model/course_provider.dart';
import 'package:we_pei_yang_flutter/schedule/model/exam_provider.dart';

class _SpiderDio extends DioAbstract {
  @override
  List<Interceptor> interceptors = [
    // CookieManager(CookieJa r()),
    cookieCachedHandler(),
    ClassesErrorInterceptor()
  ];
}

class ClassesService {
  /// 是否研究生
  static bool isMaster = false;

  /// 是否有辅修
  static bool hasMinor = false;

  /// 学期id
  static String semesterId = '';

  static final spiderDio = _SpiderDio();

  /// 获取办公网GPA、课表、考表信息
  static Future<void> getClasses(BuildContext context, String name, String pw, String captcha) async {
    await login(name, pw, captcha);
    var gpaProvider = Provider.of<GPANotifier>(context, listen: false);
    var courseProvider = Provider.of<CourseProvider>(context, listen: false);
    var examProvider = Provider.of<ExamProvider>(context, listen: false);
    Future.sync(() async {
      var mtx = Mutex();

      await mtx.acquire();
      gpaProvider.refreshGPA(
        onSuccess: () {
          mtx.release();
        },
        onFailure: (e) {
          ToastProvider.error(e.error.toString());
          mtx.release();
        },
      );

      await mtx.acquire();
      courseProvider.refreshCourse(
        onSuccess: () {
          mtx.release();
        },
        onFailure: (e) {
          ToastProvider.error(e.error.toString());
          mtx.release();
        },
      );

      await mtx.acquire();
      examProvider.refreshExam(
        onSuccess: () {
          mtx.release();
        },
        onFailure: (e) {
          ToastProvider.error(e.error.toString());
          mtx.release();
        },
      );
    });
  }

  /// 检查办公网连通
  static Future<bool> check() async {
    try {
      await spiderDio.get('http://classes.tju.edu.cn');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 登录总流程：获取session与 execution -> 填写captcha -> 进行sso登录
  static Future<void> login(String name, String pw, String captcha) async {
    // 登录sso
    final execution = await _getExecution();
    await _ssoLogin(name, pw, captcha, execution);
    await _getIdentity();

    // 刷新学期数据
    await AuthService.getSemesterInfo();
  }

  /// 退出登录
  static Future<void> logout() async {
    await spiderDio.get("http://classes.tju.edu.cn/eams/logoutExt.action");
  }

  /// 获取包含 session、execution 的 map
  static Future<String> _getExecution() async {
    var response = await spiderDio.get("https://sso.tju.edu.cn/cas/login");
    return response.data.toString().find(r'name="execution" value="(\w+)"');
  }

  /// 进行sso登录
  static Future<dynamic> _ssoLogin(
      String name, String pw, String captcha, String execution) async {
    await spiderDio.post(
      "https://sso.tju.edu.cn/cas/login",
      data: {
        "username": name,
        "password": pw,
        "captcha": captcha,
        "execution": execution,
        "_eventId": "submit"
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    return;
  }

  static Future<void> _getIdentity() async {
    late Response<dynamic> ret;
    bool redirect = false;
    String url = 'http://classes.tju.edu.cn/eams/dataQuery.action';
    while (true) {
      if (!redirect) {
        ret = await spiderDio.post(
          url,
          data: {'entityId': ''},
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            validateStatus: (status) => status! < 400,
            followRedirects: false,
          ),
        );
      } else {
        ret = await spiderDio.get(
          url,
          options: Options(
            validateStatus: (status) => status! < 400,
            followRedirects: false,
          ),
        );
      }

      if ((ret.statusCode ?? 0) == 302) {
        url = ret.headers.value('location')!;
        redirect = true;
      } else {
        redirect = false;
        break;
      }
    }
    ret = await spiderDio.post(
      url,
      data: {'entityId': ''},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    isMaster = ret.data.toString().contains(' 研究');
    hasMinor = ret.data.toString().contains('辅修');

    ret = await spiderDio.post(
      'http://classes.tju.edu.cn/eams/dataQuery.action',
      data: {"dataType": "semesterCalendar"},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final allSemester = ret.data.toString().findArrays(
        "id:([0-9]+),schoolYear:\"([0-9]+)-([0-9]+)\",name:\"(1|2)\"");

    for (var arr in allSemester) {
      if ("${arr[1]}-${arr[2]} ${arr[3]}" == _currentSemester) {
        semesterId = arr[0];
        break;
      }
    }
  }

  static String get _currentSemester {
    final date = DateTime.now();
    final year = date.year;
    final month = date.month;
    if (month > 7)
      return "${year}-${year + 1} 1";
    else if (month < 2)
      return "${year - 1}-${year} 1";
    else
      return "${year - 1}-${year} 2";
  }
}

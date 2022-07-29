// @dart = 2.12

import 'package:flutter/material.dart';
import 'package:we_pei_yang_flutter/commons/preferences/common_prefs.dart';
import 'package:we_pei_yang_flutter/commons/util/font_manager.dart';
import 'package:we_pei_yang_flutter/generated/l10n.dart';
import 'package:we_pei_yang_flutter/schedule/extension/animation_executor.dart';
import 'package:we_pei_yang_flutter/schedule/extension/logic_extension.dart';
import 'package:we_pei_yang_flutter/schedule/model/course.dart';
import 'package:we_pei_yang_flutter/schedule/view/course_dialog.dart';

class QuietCourse extends StatelessWidget {
  final String _courseName;

  QuietCourse(this._courseName);

  static const _quietBackColor = Color.fromRGBO(236, 238, 237, 1);
  static const _quiteFrontColor = Color.fromRGBO(205, 206, 210, 1);

  final _quietNameStyle = FontManager.YaQiHei.copyWith(
      color: _quiteFrontColor, fontSize: 10, fontWeight: FontWeight.bold);
  final _quietHintStyle =
      FontManager.YaHeiRegular.copyWith(color: _quiteFrontColor, fontSize: 9);

  @override
  Widget build(BuildContext context) {
    if (!CommonPreferences.otherWeekSchedule.value) return Container();
    return Container(
      decoration: BoxDecoration(
        color: _quietBackColor,
        borderRadius: BorderRadius.circular(5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        children: [
          Spacer(),
          Icon(Icons.lock, color: _quiteFrontColor, size: 15),
          SizedBox(height: 2),
          Text(formatText(_courseName),
              style: _quietNameStyle, textAlign: TextAlign.center),
          SizedBox(height: 2),
          Text(S.current.not_this_week,
              style: _quietHintStyle, textAlign: TextAlign.center),
          Spacer()
        ],
      ),
    );
  }
}

class AnimatedActiveCourse extends StatelessWidget {
  static const _duration = const Duration(milliseconds: 375);
  final List<Pair<Course, int>> _pairs;
  final bool hide;

  AnimatedActiveCourse(this._pairs, this.hide);

  final _activeNameStyle = FontManager.YaQiHei.copyWith(
      color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold);
  final _activeTeacherStyle =
  FontManager.YaHeiLight.copyWith(color: Colors.white, fontSize: 8);
  final _activeClassroomStyle =
  FontManager.Texta.copyWith(color: Colors.white, fontSize: 11);
  final _activeNameAlterStyle = FontManager.YaQiHei.copyWith(
      color: Color(0xfff1dce0), fontSize: 11, fontWeight: FontWeight.bold);
  final _activeTeacherAlterStyle =
  FontManager.YaHeiLight.copyWith(color: Color(0xfff1dce0), fontSize: 8);
  final _activeClassroomAlterStyle =
  FontManager.Texta.copyWith(color: Color(0xfff1dce0), fontSize: 11);


  bool get _alter {
    return generateColor(_pairs[0].first.name).value == Color.fromRGBO(221, 182, 190, 1.0).value;
  }

  @override
  Widget build(BuildContext context) {
    var start = _pairs[0].arrange.unitList.first;
    var day = _pairs[0].arrange.weekday;

    var teacher = '';
    _pairs[0].arrange.teacherList.forEach((str) {
      if (teacher != '') teacher += ', ';
      teacher += removeParentheses(str);
    });

    var detail = Material(
      color: generateColor(_pairs[0].first.name),
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: () => showCourseDialog(context, _pairs),
        borderRadius: BorderRadius.circular(5),
        splashFactory: InkRipple.splashFactory,
        splashColor: Color.fromRGBO(179, 182, 191, 1),
        child: hide
            ? Container()
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  children: [
                    Spacer(),
                    Text(formatText(_pairs[0].first.name),
                        style: _alter ? _activeNameAlterStyle : _activeNameStyle, textAlign: TextAlign.center),
                    SizedBox(height: 2),
                    Text(teacher,
                        style: _alter ? _activeTeacherAlterStyle : _activeTeacherStyle,
                        textAlign: TextAlign.center),
                    if (_pairs[0].arrange.location != "")
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                            replaceBuildingWord(_pairs[0].arrange.location),
                            style: _alter ? _activeClassroomAlterStyle : _activeClassroomStyle,
                            textAlign: TextAlign.center),
                      ),
                    Spacer()
                  ],
                ),
              ),
      ),
    );

    return AnimationExecutor(
      duration: _duration,
      delay: _stagger(start, day),
      builder: (BuildContext context, Animation<double> animation) {
        var curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.ease,
        );

        return Transform.scale(
          scale: Tween<double>(begin: 0.5, end: 1.0)
              .animate(curvedAnimation)
              .value,
          child: Opacity(
            opacity: Tween<double>(begin: 0.0, end: 0.8)
                .animate(curvedAnimation)
                .value,
            child: detail,
          ),
        );
      },
    );
  }

  Duration _stagger(int start, int day) => Duration(
      milliseconds: (start * 3 + day * 2) * _duration.inMilliseconds ~/ 18);
}

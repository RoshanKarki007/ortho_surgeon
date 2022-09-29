import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_sensors/flutter_sensors.dart';
import 'dart:math';
import 'package:vibration/vibration.dart';

class AccelorameterRangeAngleCalculator extends StatefulWidget {
  const AccelorameterRangeAngleCalculator({Key? key}) : super(key: key);

  @override
  State<AccelorameterRangeAngleCalculator> createState() =>
      _AccelorameterRangeAngleCalculatorState();
}

class _AccelorameterRangeAngleCalculatorState
    extends State<AccelorameterRangeAngleCalculator> {
  bool _accelAvailable = false;
  bool _gyroAvailable = false;
  List<double> _accelData = List.filled(3, 0.0);
  List<double> _gyroData = List.filled(3, 0.0);
  StreamSubscription? _accelSubscription;
  StreamSubscription? _accelSubscriptionOffset;
  StreamSubscription? _gyroSubscription;
  double firstx = 0.0;
  double firsty = 0.0;
  double firstz = 0.0;
  List firstxPoints = [];
  List firstyPoints = [];
  List firstzPoints = [];
  int firstAngle = 0;
  int currentAngle = 0;
  int offsetAngle = 0;
  @override
  void initState() {
    _checkAccelerometerStatus();
    _checkGyroscopeStatus();
    super.initState();
  }

  @override
  void dispose() {
    _stopAccelerometer();
    _stopGyroscope();
    super.dispose();
  }

  void _checkAccelerometerStatus() async {
    await SensorManager()
        .isSensorAvailable(Sensors.ACCELEROMETER)
        .then((result) {
      setState(() {
        _accelAvailable = result;
      });
    });
  }

  Future<void> _startAccelerometerOffset() async {
    if (_accelSubscription != null) return;
    if (_accelAvailable) {
      final stream = await SensorManager().sensorUpdates(
        sensorId: Sensors.ACCELEROMETER,
        interval: Sensors.SENSOR_DELAY_FASTEST,
      );
      _accelSubscriptionOffset = stream.listen((sensorEvent) {
        setState(() {
          _accelData = sensorEvent.data;
        });
      });
    }
  }

  Future<void> _startAccelerometerCurrent() async {
    if (_accelSubscription == null) return;
    if (_accelAvailable) {
      final stream = await SensorManager().sensorUpdates(
        sensorId: Sensors.ACCELEROMETER,
        interval: Sensors.SENSOR_DELAY_FASTEST,
      );
      _accelSubscription = stream.listen((sensorEvent) {
        setState(() {
          _accelData = sensorEvent.data;
        });
      });
    }
  }

  Future<List<double>> _startAccelerometerInitialAngle() async {
    if (_accelSubscription != null) return [];
    if (_accelAvailable) {
      final stream = await SensorManager().sensorUpdates(
        sensorId: Sensors.ACCELEROMETER,
        interval: Sensors.SENSOR_DELAY_FASTEST,
      );
      _accelSubscription = stream.listen((sensorEvent) async {
        var tempfirstx = sensorEvent.data[0];
        firstxPoints.add(tempfirstx);
        var tempfirsty = sensorEvent.data[1];
        firstyPoints.add(tempfirsty);
        var tempfirstz = sensorEvent.data[2];
        firstzPoints.add(tempfirstz);
      });
      await Future.delayed(Duration(milliseconds: 700), (() async {
        await Vibration.vibrate(duration: 300).whenComplete(() async {
          await _accelSubscription?.cancel();
          firstx = (firstxPoints.reduce((value, element) => value + element) /
              firstxPoints.length);
          firsty = (firstyPoints.reduce((value, element) => value + element) /
              firstyPoints.length);
          firstz = (firstzPoints.reduce((value, element) => value + element) /
              firstzPoints.length);
        });
      }));
      _resetAccelerometer();
      await _startAccelerometerCurrent();
    }
    return [firstx, firsty, firstz];
  }

  void _resetAccelerometer() {
    firstxPoints = [];
    firstyPoints = [];
    firstzPoints = [];
    if (_accelSubscription == null) {
      setState(() {
        firstAngle = 0;
        currentAngle = 0;
      });
    } else {
      _accelSubscription?.cancel();
      // _accelSubscription = null;
      setState(() {
        firstAngle = 0;
        currentAngle = 0;
      });
    }
  }

  void _stopAccelerometer() {
    if (_accelSubscription == null) return;
    _accelSubscription?.cancel();
    _accelSubscription = null;
  }

  void _checkGyroscopeStatus() async {
    await SensorManager().isSensorAvailable(Sensors.GYROSCOPE).then((result) {
      setState(() {
        _gyroAvailable = result;
      });
    });
  }

  Future<void> _startGyroscope() async {
    if (_gyroSubscription != null) return;
    if (_gyroAvailable) {
      final stream =
          await SensorManager().sensorUpdates(sensorId: Sensors.GYROSCOPE);
      _gyroSubscription = stream.listen((sensorEvent) {
        setState(() {
          _gyroData = sensorEvent.data;
        });
      });
    }
  }

  void _stopGyroscope() {
    if (_gyroSubscription == null) return;
    _gyroSubscription?.cancel();
    _gyroSubscription = null;
  }

  int getCorrectedValue(int value1, int value2) {
    // if (value1 >= value2) {
    //   return value1 - value2;
    // } else if (value2 >= value1) {
    //   return value2 - value1;
    // } else {
    //   return 0;
    // }
    var correctedValue = value1 - value2;
    correctedValue = (correctedValue + 180) % 360 - 180;
    if (correctedValue < 0) {
      correctedValue = 360 - correctedValue.abs();
    }
    return correctedValue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        padding: EdgeInsets.all(16.0),
        alignment: AlignmentDirectional.topCenter,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AngleCalculatorWidget(
              xValue: _accelData[0],
              yValue: _accelData[1],
              callback: (val) {
                currentAngle = val;
              },
            ),

            // Padding(padding: EdgeInsets.only(top: 16.0)),
            // Text('First angle: ${firstAngle.abs()}.'),
            // // Text('Current angle: ${currentAngle.abs()}'),
            Text('Final Angle: ${getCorrectedValue(firstAngle, currentAngle)}'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                MaterialButton(
                  child: Text("Start"),
                  color: Colors.green,
                  onPressed: _accelAvailable
                      ? () async {
                          var angles =
                              (await _startAccelerometerInitialAngle());
                          if (angles.isNotEmpty)
                            firstAngle = (angleCalculator(
                                firstPoint: angles[0], secondPoint: angles[1]));
                          setState(() {});
                        }
                      : null,
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                ),
                MaterialButton(
                  child: Text("Stop"),
                  color: Colors.orange,
                  onPressed:
                      _accelAvailable ? () => _stopAccelerometer() : null,
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                ),
                MaterialButton(
                  child: Text("Reset"),
                  color: Colors.red,
                  onPressed:
                      _accelAvailable ? () => _resetAccelerometer() : null,
                ),
              ],
            ),
            SizedBox(
              height: 50,
            ),
          ],
        ),
      ),
    );
  }
}

class RangeOfMotion extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  const RangeOfMotion(
    this.scaffoldKey, {
    Key? key,
  }) : super(key: key);

  @override
  _RangeOfMotionState createState() => _RangeOfMotionState();
}

class _RangeOfMotionState extends State<RangeOfMotion> {
  var allLabel;
  @override
  void didChangeDependencies() async {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
            appBar: AppBar(
              iconTheme: IconThemeData(
                color: Colors.black, //change your color here
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                "Range of motion",
                style: TextStyle(color: Colors.black),
              ),
            ),
            body: AccelorameterRangeAngleCalculator()));
  }
}

typedef IntCallback = void Function(int val);

class AngleCalculatorWidget extends StatefulWidget {
  const AngleCalculatorWidget({
    Key? key,
    this.xValue,
    this.yValue,
    @required this.callback,
  }) : super(key: key);

  final double? xValue;
  final IntCallback? callback;
  final double? yValue;
  @override
  State<AngleCalculatorWidget> createState() => _AngleCalculatorWidgetState();
}

class _AngleCalculatorWidgetState extends State<AngleCalculatorWidget> {
  int? angle;
  @override
  Widget build(BuildContext context) {
    setState(() {
      angle =
          ((atan2((widget.xValue!), (widget.yValue!)) * (180 / pi))).round();
      widget.callback!(-angle!);
    });
    return SizedBox.shrink();
  }
}

int angleCalculator({double? firstPoint, double? secondPoint}) {
  var angle = ((atan2((firstPoint!), (secondPoint!)) * (180 / pi))).round();

  // return (sqrt(angle * angle).round());
  return -angle;
}

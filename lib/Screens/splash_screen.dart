
import 'package:flutter/material.dart';
class SplashScreen extends StatefulWidget {
  final Widget? child;
  const SplashScreen({super.key, this.child});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    Future.delayed(
        Duration(seconds: 2),(){
      if (widget.child != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => widget.child!),
              (route) => false,
        );
      }

    }
    );
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
       appBar: AppBar(

          backgroundColor: Color(0xFFFFE4F3),
        ),
        body: Container(
          color: Color(0xFFFFE4F3), // تعيين لون الخلفية هنا
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Image.asset("images/logoskinglow.jpg", height: 200, width: 200),
              ],
            ),
          ),
        ),
    );

  }
}


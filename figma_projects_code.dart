// Figma-generated code for enhanced Projects tab UI
// This file contains the UI code exported from Figma
// To be integrated into class_projects.dart

// Paste your Figma-generated Flutter code here
// This will serve as the base for the enhanced Projects UI implementation

/*
Container(
    width: 450,
    height: 1020,
    child: Stack(
        children: [
            Positioned(
                left: 0,
                top: 0,
                child: Container(
                    width: 450,
                    height: 1020,
                    decoration: BoxDecoration(color: Colors.black),
                ),
            ),
            Positioned(
                left: -110,
                top: -104,
                child: Container(
                    width: 701,
                    height: 1322,
                    decoration: BoxDecoration(color: Colors.black),
                ),
            ),
            Positioned(
                left: 83.45,
                top: 280.07,
                child: Container(
                    transform: Matrix4.identity()..translate(0.0, 0.0)..rotateZ(0.02),
                    width: 253.62,
                    height: 190.29,
                    decoration: ShapeDecoration(
                        color: const Color(0xFF651C84),
                        shape: OvalBorder(),
                    ),
                ),
            ),
            Positioned(
                left: 242.91,
                top: 799.34,
                child: Container(
                    transform: Matrix4.identity()..translate(0.0, 0.0)..rotateZ(0.71),
                    width: 250.11,
                    height: 147.85,
                    decoration: ShapeDecoration(
                        color: const Color(0xFF651C84),
                        shape: OvalBorder(),
                    ),
                ),
            ),
            Positioned(
                left: 33,
                top: 55,
                child: Text(
                    'ontop.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                    ),
                ),
            ),
            Positioned(
                left: 358,
                top: 62,
                child: Container(width: 47, height: 47, child: Stack()),
            ),
            Positioned(
                left: 33,
                top: 181,
                child: Text(
                    'Projects',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                    ),
                ),
            ),
            Positioned(
                left: 325,
                top: 210,
                child: Text(
                    'Date Added',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                    ),
                ),
            ),
            Positioned(
                left: 295,
                top: 208,
                child: Container(
                    width: 24,
                    height: 24,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(),
                    child: Stack(),
                ),
            ),
            Positioned(
                left: 27,
                top: 281,
                child: Opacity(
                    opacity: 0.10,
                    child: Container(
                        width: 383,
                        height: 179,
                        decoration: ShapeDecoration(
                            gradient: LinearGradient(
                                begin: Alignment(0.50, -0.00),
                                end: Alignment(0.50, 1.00),
                                colors: [const Color(0xFFC9B9FD), const Color(0xFF58516F)],
                            ),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                            ),
                        ),
                    ),
                ),
            ),
            Positioned(
                left: 52,
                top: 341,
                child: Text(
                    'Project #3',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                    ),
                ),
            ),
            Positioned(
                left: 55,
                top: 392,
                child: Text(
                    'Collaborators: Siobhan Roy, Tom Wamb...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                    ),
                ),
            ),
            Positioned(
                left: 55,
                top: 413,
                child: Text(
                    'Description: Lorem ipsum dolor sit amet... ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                    ),
                ),
            ),
            Positioned(
                left: 359,
                top: 306,
                child: Container(
                    width: 23,
                    height: 23,
                    decoration: ShapeDecoration(
                        color: const Color(0x00D9D9D9),
                        shape: RoundedRectangleBorder(
                            side: BorderSide(
                                width: 1,
                                color: const Color(0xFFF2F2F2),
                            ),
                            borderRadius: BorderRadius.circular(6.70),
                        ),
                    ),
                ),
            ),
            Positioned(
                left: 27,
                top: 697,
                child: Opacity(
                    opacity: 0.10,
                    child: Container(
                        width: 383,
                        height: 179,
                        decoration: ShapeDecoration(
                            gradient: LinearGradient(
                                begin: Alignment(0.50, -0.00),
                                end: Alignment(0.50, 1.00),
                                colors: [const Color(0xFFC9B9FD), const Color(0xFF58516F)],
                            ),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                            ),
                        ),
                    ),
                ),
            ),
            Positioned(
                left: 55,
                top: 757,
                child: Text(
                    'Project #1',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: const Color(0xFF58516F),
                        fontSize: 24,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                    ),
                ),
            ),
            Positioned(
                left: 55,
                top: 808,
                child: Text(
                    'Collaborators: Phil Dunphy, Cameron Tu...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: const Color(0xFF58516F),
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                    ),
                ),
            ),
            Positioned(
                left: 55,
                top: 829,
                child: Text(
                    'Description: Lorem ipsum dolor sit amet... ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: const Color(0xFF58516F),
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                    ),
                ),
            ),
            Positioned(
                left: 359,
                top: 722,
                child: Container(
                    width: 23,
                    height: 23,
                    decoration: ShapeDecoration(
                        color: const Color(0x00D9D9D9),
                        shape: RoundedRectangleBorder(
                            side: BorderSide(
                                width: 1,
                                color: const Color(0xFF58516F),
                            ),
                            borderRadius: BorderRadius.circular(6.70),
                        ),
                    ),
                ),
            ),
            Positioned(
                left: 27,
                top: 489,
                child: Opacity(
                    opacity: 0.10,
                    child: Container(
                        width: 383,
                        height: 179,
                        decoration: ShapeDecoration(
                            gradient: LinearGradient(
                                begin: Alignment(0.50, -0.00),
                                end: Alignment(0.50, 1.00),
                                colors: [const Color(0xFFC9B9FD), const Color(0xFF58516F)],
                            ),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                            ),
                        ),
                    ),
                ),
            ),
            Positioned(
                left: 52,
                top: 549,
                child: Text(
                    'Project #2',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                    ),
                ),
            ),
            Positioned(
                left: 55,
                top: 600,
                child: Text(
                    'Collaborators: Jessica Day, Cece Parek...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                    ),
                ),
            ),
            Positioned(
                left: 55,
                top: 621,
                child: Text(
                    'Description: Lorem ipsum dolor sit amet... ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                    ),
                ),
            ),
            Positioned(
                left: 359,
                top: 514,
                child: Container(
                    width: 23,
                    height: 23,
                    decoration: ShapeDecoration(
                        color: const Color(0x00D9D9D9),
                        shape: RoundedRectangleBorder(
                            side: BorderSide(
                                width: 1,
                                color: const Color(0xFFF2F2F2),
                            ),
                            borderRadius: BorderRadius.circular(6.70),
                        ),
                    ),
                ),
            ),
            Positioned(
                left: 360,
                top: 723,
                child: Container(
                    width: 21,
                    height: 21,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(),
                    child: Stack(),
                ),
            ),
            Positioned(
                left: 191,
                top: 932,
                child: Container(
                    width: 55,
                    height: 55,
                    decoration: ShapeDecoration(
                        color: const Color(0xFF38064D),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                        ),
                    ),
                ),
            ),
            Positioned(
                left: 200,
                top: 906,
                child: Text(
                    '+',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 85,
                        fontFamily: 'Comic Neue',
                        fontWeight: FontWeight.w700,
                    ),
                ),
            ),
        ],
    ),
)
*/
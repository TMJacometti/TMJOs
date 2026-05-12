/*
 * TMJOs Calamares slideshow — 3 slides rotativos durante install.
 *
 * Paleta neon TMJOs:
 *   dark navy   #0a0e2a
 *   cyan glow   #00d4ff
 *   magenta     #ff00ff
 *   light text  #e6e6e6
 */

import QtQuick 2.15

Rectangle {
    id: root
    width: 800
    height: 460
    color: "#0a0e2a"

    property int currentSlide: 0
    property var slides: [
        {
            title: "Bem-vindo ao TMJOs",
            subtitle: "Distribuição Linux pra devs hardcore",
            body: "Baseado em Debian 13 (trixie) · GNOME nativo · stack proprietária de apps GTK4"
        },
        {
            title: "Sem Canonical · Sem snap · Sem frescura",
            subtitle: "Direto ao ponto",
            body: "Zero telemetria · APT direto · TMJStore proprietário · branding completo"
        },
        {
            title: "OS MELHORES · OS INSANOS",
            subtitle: "TMJOs - OS DA TMJSistemas",
            body: "Aguarde enquanto o sistema é instalado..."
        }
    ]

    Timer {
        interval: 6000
        running: true
        repeat: true
        onTriggered: root.currentSlide = (root.currentSlide + 1) % root.slides.length
    }

    Image {
        id: logo
        source: "logo.png"
        width: 96
        height: 96
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 32
        smooth: true
        fillMode: Image.PreserveAspectFit
    }

    Text {
        id: title
        text: root.slides[root.currentSlide].title
        color: "#00d4ff"
        font.pixelSize: 28
        font.bold: true
        anchors.top: logo.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 24
        horizontalAlignment: Text.AlignHCenter

        Behavior on text {
            SequentialAnimation {
                NumberAnimation { target: title; property: "opacity"; to: 0; duration: 200 }
                PropertyAction  { target: title; property: "text" }
                NumberAnimation { target: title; property: "opacity"; to: 1; duration: 400 }
            }
        }
    }

    Text {
        id: subtitle
        text: root.slides[root.currentSlide].subtitle
        color: "#ff00ff"
        font.pixelSize: 18
        font.italic: true
        anchors.top: title.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 12
        horizontalAlignment: Text.AlignHCenter

        Behavior on text {
            SequentialAnimation {
                NumberAnimation { target: subtitle; property: "opacity"; to: 0; duration: 200 }
                PropertyAction  { target: subtitle; property: "text" }
                NumberAnimation { target: subtitle; property: "opacity"; to: 1; duration: 400 }
            }
        }
    }

    Text {
        id: body
        text: root.slides[root.currentSlide].body
        color: "#e6e6e6"
        font.pixelSize: 14
        anchors.top: subtitle.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 28
        anchors.leftMargin: 48
        anchors.rightMargin: 48
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap

        Behavior on text {
            SequentialAnimation {
                NumberAnimation { target: body; property: "opacity"; to: 0; duration: 200 }
                PropertyAction  { target: body; property: "text" }
                NumberAnimation { target: body; property: "opacity"; to: 1; duration: 400 }
            }
        }
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 24
        spacing: 12

        Repeater {
            model: root.slides.length
            Rectangle {
                width: 10
                height: 10
                radius: 5
                color: index === root.currentSlide ? "#00d4ff" : "#1a1e3a"
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
    }
}

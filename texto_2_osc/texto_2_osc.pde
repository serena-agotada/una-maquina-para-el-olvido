import oscP5.*;

OscP5 oscP5;

int puerto = 12345;

PFont f;
String[][][] textos;
String texto_random, texto;

int cantVids = 59;
int cantTextosPorVideo = 4;

int indice_video = 0;
int indice_fidelidad = 0;

float sNitidez, distortionAmount, transicion;

int oscuridad;

boolean cambio_video;

void setup() {
  size(900, 630);
  //fullScreen();

  /* start oscP5, listening for incoming messages at port */
  oscP5 = new OscP5(this, puerto);

  f = createFont("SpaceMono-Regular.ttf", 18);
  textFont(f);
  textSize(48);
  textos = new String[cantVids][cantTextosPorVideo][];

  for (int t=0; t < cantVids; t++) {
    for (int f=0; f < cantTextosPorVideo; f++) {
      textos[t][f] = loadStrings("/home/sara/Desktop/Textos/" + t + "_" + f + ".txt");
      println("texto " + t + "_" + f + " cargado");
    }
  }

  oscuridad = 0;
  texto_random = "";

  transicion = 0;
}

void draw() {
  background(0);

  fill(255);
  text(texto, 35, 35, width-35, height-35);

  fill(255, 20, 255);
}

void oscEvent(OscMessage mensajeOscEntrante) {
  //delay(100);
  /*if (mensajeOscEntrante.checkAddrPattern("/video")==true) {
    if (mensajeOscEntrante.checkTypetag("i")) {
      int nuevo_indice = mensajeOscEntrante.get(0).intValue();

      if (indice_video != nuevo_indice) {
        cambio_video = true;
      } else cambio_video = false;
      indice_video = nuevo_indice;
      texto_random = textos[indice_video][indice_fidelidad][0];
    }
  }
  else if (mensajeOscEntrante.checkAddrPattern("/nitidez")==true) {
    if (mensajeOscEntrante.checkTypetag("f")) {
      distortionAmount = mensajeOscEntrante.get(0).floatValue();
    }
  }
  else if (mensajeOscEntrante.checkAddrPattern("/iFidelidad")==true) {
    if (mensajeOscEntrante.checkTypetag("i")) {
      indice_fidelidad = mensajeOscEntrante.get(0).intValue();
    }
  }
  else if (mensajeOscEntrante.checkAddrPattern("/transicion")==true) {
    if (mensajeOscEntrante.checkTypetag("f")) {
      transicion = mensajeOscEntrante.get(0).floatValue();
    }
  }*/
  
  if (mensajeOscEntrante.checkAddrPattern("/texto")==true) {
    if (mensajeOscEntrante.checkTypetag("s")) {
      texto = mensajeOscEntrante.get(0).stringValue();
    }
  }
  else if (mensajeOscEntrante.checkAddrPattern("/oscuridad")==true) {
    if (mensajeOscEntrante.checkTypetag("i")) {
      oscuridad = int(map(mensajeOscEntrante.get(0).intValue(), 0, 240, 255, 5));
    }
  }
  
}

void calcularTexto(){
  texto = textos[indice_video][indice_fidelidad][0];
  
  if (transicion < 0.15) {
    texto_random = texto;
  } else if (transicion > 0.8) {
    texto_random = "Pensando...";
  } else if (frameCount % 6 == 0) {
    texto_random = "";
    for (int i=0; i < texto.length(); i++) {
      if (random(1) < transicion && i < texto.length() && texto.charAt(i) != ' ' && texto.charAt(i) != '.' && texto.charAt(i) != ',') {
        int randChar = int( random(0, texto.length()-1) );

        while (texto.charAt(randChar) == ' ' || texto.charAt(randChar) == '.' || texto.charAt(randChar) == ',') {
          randChar = int(random(0, texto.length()-1));
        }

        texto_random += texto.charAt(randChar);
      } else if (i < texto.length()) texto_random += textos[indice_video][indice_fidelidad][0].charAt(i);
    }
  }
}

void keyPressed() {
  if (keyCode == ESC) exit();
}

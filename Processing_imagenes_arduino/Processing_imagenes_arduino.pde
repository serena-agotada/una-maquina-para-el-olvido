import oscP5.*;
import processing.serial.*;
import netP5.*;

//Envio y Recepcion Puerto Serie
Serial myPort;

OscP5 oscP5;

int cantVideos = 58;
int max_dial = 59*30;
int cantImgsPorVideo = 1;
int limite_inactividad = 10;

int puerto = 12345;

String ip_video = "192.168.100.142";
String ip_texto = "192.168.1.4";

NetAddress loc_video;
NetAddress loc_texto;

PImage[][] imgs;

int[] puntos_nitidez;

int sVideo, sNitidez;

int distSintVideo; // distancia hasta sintonizacion de video
float divisionSensor;
int randomize;
boolean shouldSetPosition;
int newIndex, sintVideoIndex, currentVideoIndex;

int clip;

int indice_imagen;

float distortionAmount, ant_distortion;

float ruido_max;

float escalar;

int oscuridad;
int tiempo_inactividad;
boolean actividad;

void setup() {
  size(1344, 756);
  //fullScreen();
  background(0);

  // Puerto de Arduino
  myPort = new Serial(this, "COM3", 9600);
  myPort.bufferUntil('\n');

  loc_video  = new NetAddress(ip_video, puerto);
  loc_texto  = new NetAddress(ip_texto, puerto);

  /* start oscP5, listening for incoming messages at port */
  oscP5 = new OscP5(this, puerto);

  imgs = new PImage[cantVideos][cantImgsPorVideo];

  puntos_nitidez = new int[cantVideos];


  for (int i=0; i < cantVideos; i++) {
    for (int si=0; si < cantImgsPorVideo; si++) {
      imgs[i][si] = loadImage("../Imagenes/" + i + "_" + si + ".jpg");
      imgs[i][si].loadPixels();

      println("imagen: " + i + "_" + si + " cargada");
    }

    puntos_nitidez[i] = int(random(1023));
  }

  divisionSensor = (float)max_dial / float(cantVideos-1);

  shouldSetPosition = false;

  clip = 0;

  ant_distortion = 0;

  ruido_max = width/11;

  sVideo = 0;
  sNitidez = 0;

  oscuridad = 0;
  tiempo_inactividad = 0;

  OscMessage n = new OscMessage("/oscuridad");
  n.add(0);
  oscP5.send(n, loc_video);
  oscP5.send(n, loc_texto);

  escalar = float(width)/float(imgs[0][0].width);
}


void draw() {
  
  // CALCULO DE VARIABLES
  sintVideoIndex = constrain( round(sVideo / divisionSensor), 0, cantVideos-1); // calculo de indice a sintonizar
  
  int nDistSint = int(abs(sVideo - (divisionSensor * sintVideoIndex))); // calculo la nueva distancia entre el valor del sensor y el valor para sintonizacion
  if (nDistSint != distSintVideo) {
    OscMessage ds = new OscMessage("/distSint");
    ds.add(nDistSint);
    oscP5.send(ds, loc_video);

    distSintVideo = nDistSint;
  }
  randomize = (int)map(distSintVideo, divisionSensor/2, 0, 1, frameRate);

  // CAMBIO DE CLIP
  if (distSintVideo > 3) {
    cambiarClip();
  } else if (currentVideoIndex != sintVideoIndex) {
    newIndex = sintVideoIndex;
  }

  if (clip != newIndex) {
    clip = newIndex;
    indice_imagen = int(random(cantImgsPorVideo));
    escalar = float(width)/float(imgs[clip][indice_imagen].width);
  }

  // CALCULO NITIDEZ DEL VIDEO
  float distN = abs( puntos_nitidez[clip] - sNitidez );
  float dist_max = 1;

  if (puntos_nitidez[clip] < 1023/2)
    dist_max = 1023 - puntos_nitidez[clip];
  else
    dist_max = puntos_nitidez[clip];

  if (clip == sintVideoIndex && distSintVideo < 10)
    distortionAmount = map(distN, 0, dist_max, 0, 1);
  else if (clip == sintVideoIndex)
    distortionAmount = map(distN, 0, dist_max, 0.05, 1);
  else
    distortionAmount = map(distN, 0, dist_max, 0.7, 1);

  // ACTUALIZO INDICE DE VIDEO Y ENVIO A LAS OTRAS COMPUS
  if (newIndex != currentVideoIndex) {
    OscMessage cv = new OscMessage("/video");
    cv.add(newIndex);
    oscP5.send(cv, loc_video);
    oscP5.send(cv, loc_texto);
    
    delay(500);

    currentVideoIndex = newIndex;
  }

  // ENVIO NITIDEZ
  OscMessage n = new OscMessage("/nitidez");
  n.add(distortionAmount);
  oscP5.send(n, loc_video);
  oscP5.send(n, loc_texto);


  // DISTORSIONO IMAGEN
  image(imgs[clip][indice_imagen], 0, 0, width, height);

  loadPixels();
  float esc = float(pixels.length) / float(imgs[clip][indice_imagen].pixels.length);
  println(esc);

  for (int i = 0; i < pixels.length; i++) {

    float r = red(pixels[i]);
    float g = green(pixels[i]);
    float b = blue(pixels[i]);

    int n_i = i;

    if (distortionAmount > 0.01) {
      n_i = int( constrain(i + random(-distortionAmount*ruido_max, distortionAmount*ruido_max), 0, pixels.length-1) );

      r += constrain(random(-distortionAmount*100, distortionAmount*100), 0, 255);
      g += constrain(random(-distortionAmount*ruido_max, distortionAmount*ruido_max), 0, 255);
      b += constrain(random(-distortionAmount*ruido_max, distortionAmount*ruido_max), 0, 255);
    }

    color c = color(r, g, b);

    pixels[n_i] = c;
  }

  updatePixels();

  ant_distortion = distortionAmount;

  // oscurezco la pantalla
  monitorearActividad();
  fill(0, oscuridad);
  rect(0, 0, width, height);

  //println("inactividad " + tiempo_inactividad, "| oscuridad " + oscuridad, "| sVideo " + sVideo, "| sNitidez " +  sNitidez, "| distSintVideo " + distSintVideo, "| sintVideoIndex " + sintVideoIndex, "| escalar " + escalar);
}

void cambiarClip() {
  if (randomize != 0 && frameCount % randomize == 0) {
    shouldSetPosition = true;

    // Guardo la posicion del video
    //videoPositions[currentVideoIndex] = videoPlayer.getPosition();

    // cuanto mas cerca este el sensor a un punto de sintonizacion (distSintVideo es mas cercano a 0), mas probabilidad de que aparezca ese video
    float prob = random(distSintVideo);

    if (prob <= distSintVideo/2) {
      newIndex = sintVideoIndex;
    }
    // sino cambio a un video random distinto al actual
    else {
      while (newIndex == currentVideoIndex) {
        newIndex = (int) random(0, cantVideos - 1);
      }
    }
  }
}

void monitorearActividad() {
  if (actividad) {
    tiempo_inactividad = 0;
    actividad = false;
  } else {
    tiempo_inactividad++;
  }

  // ajusto oscuridad - comienza a apagarse cuando pasan 10 seg
  if (tiempo_inactividad > (limite_inactividad*frameRate)) {
    oscuridad = constrain(oscuridad+1, 0, 240);

    OscMessage n = new OscMessage("/oscuridad");
    n.add(oscuridad);
    oscP5.send(n, loc_video);
    oscP5.send(n, loc_texto);
  } else if ( tiempo_inactividad < 3 && oscuridad > 0) {
    oscuridad = constrain(oscuridad-=30, 0, 240);

    OscMessage n = new OscMessage("/oscuridad");
    n.add(oscuridad);
    oscP5.send(n, loc_video);
    oscP5.send(n, loc_texto);
  }
}

void serialEvent(Serial myPort) {

  String inString = myPort.readStringUntil('\n');

  if (inString != null) {
    inString = trim(inString);
    int [] datos = int (split(inString, " "));

    if (datos.length >= 3) {

      if (sVideo != datos[0]) {

        if ( abs(sVideo - datos[0]) > 0) actividad = true; // registro actividad

        sVideo = int(lerp(sVideo, datos[0], 0.8));

        OscMessage sv = new OscMessage("/sVideo"); // envio valor del sensor de nitidez a raspi
        sv.add(sVideo);
        oscP5.send(sv, loc_video);
        //oscP5.send(sv, loc_texto);
      }

      if (sNitidez != datos[1]) {

        if ( abs(sNitidez - datos[1]) > 3) actividad = true; // registro actividad si el cambio es grande

        sNitidez = datos[1];
      }
    }
  }
}

void oscEvent(OscMessage mensajeOscEntrante) {
  if (mensajeOscEntrante.checkAddrPattern("/video")==true) {
    if (mensajeOscEntrante.checkTypetag("i")) {
      int indice_recibido = mensajeOscEntrante.get(0).intValue();

      currentVideoIndex = indice_recibido;

      println("indice recibido: ", indice_recibido);
    }
  }
}

void keyPressed() {
  if (keyCode == ESC) exit();
}

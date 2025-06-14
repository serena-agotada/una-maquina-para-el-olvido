import oscP5.*;
import processing.serial.*;
import netP5.*;

//Envio y Recepcion Puerto Serie
Serial myPort;

OscP5 oscP5;

int cantVideos = 59;
int max_dial = 59*30;
int cantImgsPorVideo = 1;
int limite_inactividad = 10;

int puerto = 12345;

String ip_video = "192.168.100.122";
String ip_texto = "192.168.100.104";

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
  myPort = new Serial(this, "COM13", 9600);
  myPort.bufferUntil('\n');

  loc_video  = new NetAddress(ip_video, puerto);
  loc_texto  = new NetAddress(ip_texto, puerto);

  /* start oscP5, listening for incoming messages at port */
  oscP5 = new OscP5(this, puerto);

  imgs = new PImage[cantVideos][cantImgsPorVideo];

  puntos_nitidez = new int[cantVideos];


  for (int i=0; i < cantVideos; i++) {
    for (int si=0; si < cantImgsPorVideo; si++) {
      imgs[i][si] = loadImage("C:/Users/sarad/Documents/Facultad/2023/tesis/arquitectura/Imagenes/" + i + "_" + si + ".jpg");
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

  escalar = width/imgs[0][0].width;


  loadPixels();
}


void draw() {
  //background(0);
  // CALCULO DE VARIABLES
  sintVideoIndex = constrain( round(sVideo / divisionSensor), 0, cantVideos-1); // calculo de indice a sintonizar
  //println(sintVideoIndex);
  int nDistSint = int(abs(sVideo - (divisionSensor * sintVideoIndex))); // calculo la nueva distancia entre el valor del sensor y el valor para sintonizacion
  if (nDistSint != distSintVideo) {
    OscMessage ds = new OscMessage("/distSint");
    ds.add(nDistSint);
    oscP5.send(ds, loc_video);
    //oscP5.send(cv, loc_texto);
    
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

    currentVideoIndex = newIndex;
  }

// ENVIO NITIDEZ
  OscMessage n = new OscMessage("/nitidez");
  n.add(distortionAmount);
  oscP5.send(n, loc_video);
  oscP5.send(n, loc_texto);


// DISTORSIONO IMAGEN
  if (distortionAmount != ant_distortion || distSintVideo <= 1000) {

    for (int x = 0; x < imgs[clip][indice_imagen].width; x++) {
      for (int y = 0; y < imgs[clip][indice_imagen].height; y++ ) {
        // Calculate the 1D location from a 2D grid
        int loc = x + y*imgs[clip][indice_imagen].width;

        float r = red(imgs[clip][indice_imagen].pixels[loc]);
        float g = green(imgs[clip][indice_imagen].pixels[loc]);
        float b = blue(imgs[clip][indice_imagen].pixels[loc]);

        int n_loc = constrain(y*width + x, 0, pixels.length-1);

        if (distortionAmount > 0.01) {
          int n_x = int(x + random(-distortionAmount*ruido_max, distortionAmount*ruido_max));
          int n_y = int(y + random(-distortionAmount*ruido_max, distortionAmount*ruido_max));

          n_loc = constrain(n_y*width + n_x, 0, pixels.length-1);

          r += constrain(random(-distortionAmount*100, distortionAmount*100), 0, 255);
          g += constrain(random(-distortionAmount*ruido_max, distortionAmount*ruido_max), 0, 255);
          b += constrain(random(-distortionAmount*ruido_max, distortionAmount*ruido_max), 0, 255);
        }

        color c = color(r, g, b);

        pixels[n_loc] = c;
      }
    }

    updatePixels();
  } else {
    image(imgs[clip][indice_imagen], 0, 0, width, height);
  }

  ant_distortion = distortionAmount;

  // oscurezco la pantalla
  monitorearActividad();
  fill(0, oscuridad);
  rect(0, 0, width, height);

  println("inactividad " + tiempo_inactividad, "| oscuridad " + oscuridad, "| sVideo " + sVideo, "| sNitidez " +  sNitidez, "| distSintVideo " + distSintVideo, "| sintVideoIndex " + sintVideoIndex,  "| escalar " + escalar);
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

    if (datos.length >= 2) {

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


void keyPressed() {
  if (keyCode == ESC) exit();
}

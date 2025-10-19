import oscP5.*;
//import processing.serial.*;
import netP5.*;

//Envio y Recepcion Puerto Serie
//Serial myPort;

OscP5 oscP5;

int cantVideos = 3;
int max_dial = (cantVideos+1)*30;
int cantImgsPorVideo = 4;
int limite_inactividad = 10;

int puerto = 12345;

String ip_video = "192.168.100.142";
String ip_texto = "192.168.100.104";

NetAddress loc_video;
NetAddress loc_texto;

PImage[][] imgs;

int[] puntos_nitidez;

int sVideo, sNitidez;

int distSintVideo; // distancia hasta sintonizacion de video
float divisionSensor, divisionFidelidad;
int randomize;
boolean shouldSetPosition;
int newIndex, sintVideoIndex, currentVideoIndex;

int clip;

int indice_imagen;

float distortionAmount, ant_distortion;
float transicionImagenes;

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
  //myPort = new Serial(this, "COM13", 9600);
  //myPort.bufferUntil('\n');

  loc_video  = new NetAddress(ip_video, puerto);
  loc_texto  = new NetAddress(ip_texto, puerto);

  /* start oscP5, listening for incoming messages at port */
  oscP5 = new OscP5(this, puerto);

  imgs = new PImage[cantVideos][cantImgsPorVideo];

  puntos_nitidez = new int[cantVideos];


  for (int v=0; v < cantVideos; v++) {
    for (int si=0; si < cantImgsPorVideo; si++) {
      imgs[v][si] = loadImage("../Imagenes/" + v + "_" + si + ".png");
      imgs[v][si].loadPixels();

      println("imagen: " + v + "_" + si + " cargada");
    }

    puntos_nitidez[v] = int(random(1023));
  }

  divisionSensor = (float)max_dial / float(cantVideos-1);
  divisionFidelidad = 1/float(cantImgsPorVideo-1);

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
    //indice_imagen = int(random(cantImgsPorVideo));
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

  // CALCULO INDICE DE IMAGEN
  indice_imagen = int(constrain(distortionAmount * cantImgsPorVideo, 0, cantImgsPorVideo-1));

  // MUESTRO IMAGEN
  image(imgs[clip][indice_imagen], 0, 0, width, height);

  distorsionImagen();


  ant_distortion = distortionAmount;

  // oscurezco la pantalla
  monitorearActividad();
  fill(0, oscuridad);
  rect(0, 0, width, height);

  dibujarGrillaReferencia();

  //println("inactividad " + tiempo_inactividad, "| oscuridad " + oscuridad, "| sVideo " + sVideo, "| sNitidez " +  sNitidez, "| distSintVideo " + distSintVideo, "| sintVideoIndex " + sintVideoIndex, "| escalar " + escalar);
}

// --------------------------------------------------------------------------------
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

    //println(newIndex);
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

// --------------------------------------------------------------------------------------------------------------------------

void distorsionImagen() {
  if (distortionAmount > 0.125) {
    //transicionImagenes = map(distortionAmount / cantImgsPorVideo, 0, divisorFidelidad, 0, 1);
    //transicionImagenes = abs(distortionAmount - (divisionFidelidad * indice_imagen));
    transicionImagenes = 1 - abs(2 * (distortionAmount * 1.5 % 1) - 1);
    //refe: int nDistSint = int(abs(sVideo - (divisionSensor * sintVideoIndex))); // calculo la nueva distancia entre el valor del sensor y el valor para sintonizacion
    //refe: indice_imagen = int(constrain(distortionAmount * cantImgsPorVideo, 0, 3));
    println(distortionAmount, transicionImagenes);
  }
  if (transicionImagenes > 0) {
    loadPixels();
    //float esc = float(pixels.length) / float(imgs[clip][indice_imagen].pixels.length);
    //println(esc);

    for (int i = 0; i < pixels.length; i++) {

      float r = red(pixels[i]);
      float g = green(pixels[i]);
      float b = blue(pixels[i]);

      int n_i = i;

      if (transicionImagenes > 0.01) {
        n_i = int( constrain(i + random(-transicionImagenes*ruido_max, transicionImagenes*ruido_max), 0, pixels.length-1) );

        r += constrain(random(-transicionImagenes*100, transicionImagenes*100), 0, 255);
        g += constrain(random(-transicionImagenes*ruido_max, transicionImagenes*ruido_max), 0, 255);
        b += constrain(random(-transicionImagenes*ruido_max, transicionImagenes*ruido_max), 0, 255);
      }

      color c = color(r, g, b);

      pixels[n_i] = c;
    }

    updatePixels();
  }
}

// --------------------------------------------------------------------------------------------------------------------------

void mouseMoved() {
  int nSVideo = int(map(mouseX, 0, width, 0, max_dial));

  if (sVideo != nSVideo) {

    if ( abs(sVideo - nSVideo) > 0) actividad = true; // registro actividad

    sVideo = int(lerp(sVideo, nSVideo, 0.8));

    OscMessage sv = new OscMessage("/sVideo"); // envio valor del sensor de nitidez a raspi
    sv.add(sVideo);
    oscP5.send(sv, loc_video);
    //oscP5.send(sv, loc_texto);
  }

  int nSNitidez = int(map(mouseY, 0, height, 0, 1023));

  if ( abs(sNitidez - nSNitidez) > 3) actividad = true; // registro actividad si el cambio es grande

  sNitidez = nSNitidez;

  //println(sNitidez);
}

// --------------------------------------------------------------------------------------------------------------------------

void dibujarGrillaReferencia() {
  for (int i=0; i < cantVideos; i++) {
    line((width/(cantVideos-1))* i, 0, (width/(cantVideos-1))* i, height);
  }
  
  float pNitPantalla = map(puntos_nitidez[clip], 0, 1023, 0, height);
  
  line(0, pNitPantalla, width, pNitPantalla);
  
  /*for (int i=0; i < cantImgsPorVideo; i++) {
    line(0, height/(cantImgsPorVideo-1), width, height/(cantImgsPorVideo-1));
  }*/
}

// --------------------------------------------------------------------------------------------------------------------------

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

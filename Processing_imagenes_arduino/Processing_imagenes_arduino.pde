import oscP5.*;
import processing.serial.*;
import netP5.*;

//Envio y Recepcion Puerto Serie
Serial myPort;

OscP5 oscP5;

int cantVideos = 10;
int max_dial = (cantVideos+1)*30;
int cantImgsPorVideo = 4;
int limite_inactividad = 10;

int puerto = 12345;

String ip_video = "192.168.1.4";
String ip_texto = "192.168.100.4";

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
  //size(1920, 1080);
  fullScreen();
  pixelDensity(1);
  noSmooth();

  // Puerto de Arduino
  myPort = new Serial(this, "COM8", 9600);
  myPort.bufferUntil('\n');

  loc_video  = new NetAddress(ip_video, puerto);
  loc_texto  = new NetAddress(ip_texto, puerto);

  /* start oscP5, listening for incoming messages at port */
  oscP5 = new OscP5(this, puerto);

  imgs = new PImage[cantVideos][cantImgsPorVideo];

  puntos_nitidez = new int[cantVideos];


  for (int i=0; i < cantVideos; i++) {
    for (int si=0; si < cantImgsPorVideo; si++) {
      imgs[i][si] = loadImage("../Imagenes/" + i + "_" + si + ".png");
      imgs[i][si].resize(width, height);
      //imgs[i][si].loadPixels();

      println("imagen: " + i + "_" + si + " cargada");
      
    }

    puntos_nitidez[i] = int(random(1023));
  }

  divisionSensor = (float)max_dial / float(cantVideos-1);
  divisionFidelidad = 1/float(cantImgsPorVideo);

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

  indice_imagen = int(constrain(distortionAmount * cantImgsPorVideo, 0, cantImgsPorVideo-1));
  //println(distortionAmount, indice_imagen);

  // DISTORSIONO IMAGEN
  mostrarImagen();


  ant_distortion = distortionAmount;

  // oscurezco la pantalla
  monitorearActividad();
  fill(0, oscuridad);
  rect(0, 0, width, height);

  //dibujarGrillaReferencia();

  //println("inactividad " + tiempo_inactividad, "| oscuridad " + oscuridad, "| sVideo " + sVideo, "| sNitidez " +  sNitidez, "| distSintVideo " + distSintVideo, "| sintVideoIndex " + sintVideoIndex, "| escalar " + escalar);
}

// --------------------------------------------------------------------------------------------------------------------------

void mostrarImagen() {
  if (distortionAmount > 1/float(cantImgsPorVideo)/2) {
    transicionImagenes = calcularTransicionImgs(distortionAmount);
    println(transicionImagenes);
    

    if (transicionImagenes < 0.1) {
      image(imgs[clip][indice_imagen], 0, 0);
    }
    loadPixels();

    for (int i = 0; i < pixels.length; i+= 1+random(transicionImagenes*10)) {

      float r = red(imgs[clip][indice_imagen].pixels[i]);
      float g = green(imgs[clip][indice_imagen].pixels[i]);
      float b = blue(imgs[clip][indice_imagen].pixels[i]);

      int n_i = i;

      n_i = int( constrain(i + random(-transicionImagenes*ruido_max, transicionImagenes*ruido_max), 0, pixels.length-1) );

      r += constrain(random(-transicionImagenes*ruido_max, transicionImagenes*ruido_max), 0, 255);
      g += constrain(random(-transicionImagenes*ruido_max, transicionImagenes*ruido_max), 0, 255);
      b += constrain(random(-transicionImagenes*ruido_max, transicionImagenes*ruido_max), 0, 255);


      color c = color(r, g, b);

      pixels[n_i] = c;
    }

    updatePixels();
  } else image(imgs[clip][indice_imagen], 0, 0);
}

// --------------------------------------------------------------------------------------------------------------------------

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

// --------------------------------------------------------------------------------------------------------------------------

void dibujarGrillaReferencia() {
  strokeWeight(1);
  stroke(0);
  for (int i=0; i < cantVideos; i++) {
    line((width/(cantVideos-1))* i, 0, (width/(cantVideos-1))* i, height);
  }

  stroke(255);
  float pNitPantalla = map(sNitidez, 0, 1023, 0, height);

  line(0, pNitPantalla, width, pNitPantalla);

  for (int i=0; i < cantImgsPorVideo; i++) {
    line(0, i*(height/(cantImgsPorVideo)), width, i*(height/(cantImgsPorVideo)));
  }

  strokeWeight(2);

  for (float i = 0; i <= 1; i+=0.01) {
    //transicionImagenes = pow(abs(transicionImagenes), 0.5) * Math.signum(transicionImagenes);
    transicionImagenes = calcularTransicionImgs(i);

    line(width/2, height*i, width/2 + transicionImagenes*100, height*i);
  }
}

// --------------------------------------------------------------------------------------------------------------------------

float calcularTransicionImgs(float i) {

  float a = i * PI*cantImgsPorVideo + PI/(cantImgsPorVideo/2);
  //float t = abs(sin(a));
  //transicionImagenes = pow(abs(transicionImagenes), 0.5) * Math.signum(transicionImagenes);
  float t = abs(tan(1.5 * sin(a)));
  
  return t/15;
}

// --------------------------------------------------------------------------------------------------------------------------

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

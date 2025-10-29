import oscP5.*;
import processing.serial.*;
import netP5.*;

//Envio y Recepcion Puerto Serie
Serial myPort;

OscP5 oscP5;

int cantVideos = 65;
int max_dial = (cantVideos+1)*10;
int cantImgsPorVideo = 4;
int limite_inactividad = 10;

int puerto = 12345;

String ip_video = "192.168.100.135";
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

//TEXTO ---------------
String[][] textos;
String texto_random, texto;
int caracteres_escritos;

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

  // TEXTO -----------------------------------------------------------
  textos = new String[cantVideos][cantVideos];

  for (int t=0; t < cantVideos; t++) {
    for (int f=0; f < cantImgsPorVideo; f++) {
      String[] archivo = loadStrings("../Textos/" + t + "_" + f + ".txt");
      textos[t][f] = archivo[0];

      for (int l=1; l < archivo.length; l++) {
        textos[t][f] += "\n";
        textos[t][f] += archivo[l];
      }
      println("texto " + t + "_" + f + " cargado");
    }
  }
  texto_random = "";

  caracteres_escritos = 0;
}

// --------------------------------------------------------------------------------------------

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
  if (distSintVideo > 2) {
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

  if (clip == sintVideoIndex && distSintVideo < 3)
    distortionAmount = map(distN, 0, dist_max, 0, 1);
  else
    distortionAmount = 1;

  if (ant_distortion != distortionAmount) {
    // ENVIO NITIDEZ
    OscMessage n = new OscMessage("/nitidez");
    n.add(distortionAmount);
    oscP5.send(n, loc_video);
    oscP5.send(n, loc_texto);

    // CALCULO INDICE DE IMAGEN / TEXTO
    int n_indice = int(constrain(distortionAmount * cantImgsPorVideo, 0, cantImgsPorVideo-1));
    if (n_indice != indice_imagen) {
      indice_imagen = n_indice;
      caracteres_escritos = 0;

      OscMessage iFid = new OscMessage("/iFidelidad"); // envio valor del sensor de nitidez a raspi
      iFid.add(indice_imagen);
      //oscP5.send(iFid, loc_video);
      oscP5.send(iFid, loc_texto);
      //println(distortionAmount, indice_imagen);
    }

    ant_distortion = distortionAmount;
  }

  // ACTUALIZO INDICE DE VIDEO Y ENVIO A LAS OTRAS COMPUS
  if (newIndex != currentVideoIndex) {
    OscMessage cv = new OscMessage("/video");
    cv.add(newIndex);
    oscP5.send(cv, loc_video);
    oscP5.send(cv, loc_texto);

    delay(500);

    currentVideoIndex = newIndex;
  }

  calcularTexto();

  // DISTORSIONO IMAGEN
  mostrarImagen();
  filter(BLUR, map(transicionImagenes, 0, 1, 1, 3));

  // oscurezco la pantalla
  monitorearActividad();
  fill(0, oscuridad);
  rect(0, 0, width, height);
  
  barra_inferior();


  //dibujarGrillaReferencia();

  //println("inactividad " + tiempo_inactividad, "| oscuridad " + oscuridad, "| sVideo " + sVideo, "| sNitidez " +  sNitidez, "| distSintVideo " + distSintVideo, "| sintVideoIndex " + sintVideoIndex, "| escalar " + escalar);
}

// --------------------------------------------------------------------------------------------------------------------------

void mostrarImagen() {
  if (distortionAmount > 1/float(cantImgsPorVideo)/2) {

    float nTransicion = 1;
    if (distSintVideo < 4) {
      nTransicion = calcularTransicionImgs(distortionAmount);
    }

    if (transicionImagenes != nTransicion) {
      transicionImagenes = nTransicion;

      OscMessage trans = new OscMessage("/transicion");
      trans.add(transicionImagenes);
      //oscP5.send(n, loc_video);
      oscP5.send(trans, loc_texto);
    }

    //println(transicionImagenes);
    if (transicionImagenes < 0.1 && caracteres_escritos > texto.length() - 25) {
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
  } else if(caracteres_escritos > texto.length() - 25) image(imgs[clip][indice_imagen], 0, 0);
}

// --------------------------------------------------------------------------------------------------------------------------

void cambiarClip() {
  if (randomize != 0 && frameCount % randomize == 0) {
    shouldSetPosition = true;

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

    caracteres_escritos = 0;
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
        oscP5.send(sv, loc_texto);
      }

      if (sNitidez != datos[1]) {

        //if ( abs(sNitidez - datos[1]) > 3) actividad = true; // registro actividad si el cambio es grande

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

// ------------------------------------------------------------------------------------------------------
void barra_inferior(){
  int ancho_barra = width;
  int alto_barra = 20;
  int xSensor = int(map(sVideo, 0, max_dial, 0, ancho_barra)); // valor traducido en x del sensor
  float div = ((float)ancho_barra / (float)(cantVideos - 1));
    
  // fondo barra inferior
  fill(0);
  rect(0, height-alto_barra, width, alto_barra);

  for (int i = 0; i < cantVideos; i++) {
    
    int xSints = int(i * div);
      
    // marcas de sintonizacion
    if( abs(xSensor - xSints) < div*0.19 ){
      // verde de sintonizacion
      fill(0, 255, 0);
      rect(xSints-div*0.25, height-alto_barra, div*0.5, alto_barra);
        
      //text("0x"+ ofToString(currentVideoIndex) + "ae" + ofToString(distSintVideo) + "c" + ofToString((int) ofMap(distortionAmount, 0, 1, 100, 999)) , xSints-5, ofGetHeight()-alto_barra-10);
    }
    else{
      // puntos no sintonizados
      fill(180);
      rect(xSints-div*0.15, height-alto_barra, div*0.3, alto_barra);
    }
  }
  // barra valor sensor
  fill(255, 0, 0);
  rect(xSensor, height-alto_barra, 3, alto_barra);
}


// --------------------------------------------------------------------------------------------------------------------------

void keyPressed() {
  if (keyCode == ESC) exit();
}

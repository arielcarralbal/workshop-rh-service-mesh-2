# Workshop OpenShift Service Mesh

En este Workshop usaremos la aplicación de ejemplo Bookinfo.

La aplicación Bookinfo muestra información sobre un libro, similar a una sola entrada de catálogo de una librería en línea. La aplicación muestra una página que: describe el libro, da detalles del libro (ISBN, número de páginas y otra información) y muestra reseñas del libro.

La aplicación Bookinfo consta de estos 4 microservicios:

1. El microservicio de la página del producto llama a los detalles y revisa los microservicios para completar la página.
2. El microservicio de detalles contiene información del libro.
3. El microservicio de reseñas contiene reseñas de libros. También llama al microservicio de calificaciones.
4. El microservicio de calificaciones contiene información de clasificación de libros que acompaña a la reseña de un libro.

Hay tres versiones del microservicio de reseñas:

1. La versión v1 no llama al Servicio de calificaciones.
2. La versión v2 llama al servicio de calificaciones y muestra cada calificación como de una a cinco estrellas negras.
3. La versión v3 llama al servicio de calificaciones y muestra cada calificación como de una a cinco estrellas rojas.


![](bookinfo-page.png)



## Instalación

### 1. Prerequisitos

Debemos tener instalados los siguientes operadores en OpenShift (ya fueron instalados en el cluster para de Workshop):

- OpenShift Elasticsearch
- Jaeger
- Kiali
- Red Hat OpenShift Service Mesh

Debemos contar con los siguientes comandos (Opcional):

- git ([Descargar aquí](https://git-scm.com/downloads "Descargar git"))
- oc ([Descargar aquí](https://access.redhat.com/downloads/content/290/ver=4.10/rhel---8/4.10.10/x86_64/product-software "Descargar oc"))
- Visual Studio Code (Recomendado) ([Descargar aquí](https://code.visualstudio.com/download "Descargar VS Code"))

Si no cuentan con ellos o no los pueden instalar, al ingresar al clustes podrás ver un namespace llamado dev-toolbox-N; en este namespace podrán acceder a una terminal desde Workloads > Pods, e ingresando al único pod listado hacer click en la solapa Terminal.

### 2. Deploy de microservicios

Ejecutamos los siguientes comandos. 

IMPORTANTE: En el primero reemplazamos la "N" con el grupo asignado.
```sh
echo "export PROJECT=workshop-mesh-apps-N" >> $HOME/.bashrc
source $HOME/.bashrc
mkdir ~/workshop-mesh && cd "$_"
git clone https://github.com/arielcarralbal/workshop-rh-service-mesh-2
cd workshop-service-mesh
```
Luego de clonar este repositorio, iniciamos sesión en OpenShift.

IMPORTANTE: Reemplazamos la "N" con el número de grupo asignado.
```sh
oc login -u userN -p r3dh4t1!
```

Verificamos los valores de las siguientes variables de entorno antes de continuar:
- *PROJECT* con el nombre del proyecto (namespace). 

```sh
echo $PROJECT
```
Debemos ver *workshop-mesh-apps-N* ("N" es el número de grupo asignado).

Desplegamos la app y visualizamos los pods.
```sh
oc apply -n $PROJECT -f bookinfo.yaml
```

Agregamos etiquetas y anotaciones.

```sh
chmod +x tags.sh
./tags.sh
```

Creamos una nueva variable de entorno:
- *GATEWAY_URL* con la ruta expuesta (Ej: workshop-mesh-apps-N.apps.kali.rlab.sh).

En el primero reemplazamos la "N" con el grupo asignado.
```sh
echo "export GATEWAY_URL=workshop-mesh-apps-N.apps.kali.rlab.sh" >> $HOME/.bashrc
source $HOME/.bashrc
echo $GATEWAY_URL
```
Editamos el archivo 
**bookinfo/Gateway-VirtualService.yaml** y en *host* reemplazamos "N" con el grupo asignado.
```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: gateway-workshop
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: cliente-certs
    hosts:
    - 'workshop-mesh-apps-N.apps.kali.rlab.sh' # Editar N
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: gateway-workshop
spec:
  hosts:
  - 'workshop-mesh-apps-N.apps.kali.rlab.sh' # Editar N
  gateways:
  - gateway-workshop
  http:
  - match:
    - uri:
        exact: /productpage
    - uri:
        prefix: /static
    - uri:
        exact: /login
    - uri:
        exact: /logout
    - uri:
        prefix: /api/v1/products
    route:
    - destination:
        host: productpage
        port:
          number: 9080

```

Por último creamos el Gateway y VirtualService con el yaml recién editado:
```sh
 oc apply -f bookinfo/Gateway-VirtualService.yaml  -n $PROJECT
```
Con la creación del Gateway, OpenShift crea la ruta (Route) automáticamente.
Veamos cómo quedó todo en OpenShift y accedamos a la app.

```sh
echo "https://$GATEWAY_URL/productpage"
```

Copie y pegue el resultado en un navegador web para verificar que la página del producto Bookinfo esté desplegada.

Finalmente, agregue reglas de destino predeterminadas (lo modificaremos más adelante para afectar el enrutamiento de las solicitudes):

```sh
oc apply -f bookinfo/networking/destination-rule-all.yaml -n $PROJECT
```

# Ejercicios
# Control de tráfico
## Rutear a una versión específica

Vamos a redireccionar todo el tráfico a la v1 con un VirtualService.

```sh
oc apply -f bookinfo/networking/virtual-service-all-v1.yaml -n $PROJECT
```
Verifiquemos que en la web ya no vemos más las estrellas de ratings (reviews V1 no accede al servicio ratings).

## Rutear a versión por encabezado HTTP

Este caso nos permite redireccionar el tráfico a una versión específica basado en el valor de encabezado. Con la siguiente configuración lograremos:

1. Por defecto veremos reviews v1 (sin estrellas)
2. El usuario "redhat" verá reviews v2 (estrellas negras)
3. Si se accede desde un iPhone veremos reviews v3 (estrellas rojas)

```sh
oc apply -f bookinfo/networking/virtual-service-reviews-test-v2.yaml -n $PROJECT
```
Verificamos los 3 casos.

`CHALLENGE: ¡Probemos otros encabezados!`

Volvemos a redirigir todo a v1.
```sh
oc apply -f bookinfo/networking/virtual-service-all-v1.yaml -n $PROJECT
```

## Canary Release
Mediante VirtualService vamos a redirecionar el 90% del tráfico a la v1 y sólo el 10% a la v2.

```sh
oc apply -f bookinfo/networking/virtual-service-reviews-90-10.yaml -n $PROJECT
```
`CHALLENGE: ¡Probemos otras opciones de balanceo!`

----
# Inyección de fallas
## Inyectar una demora

```sh
oc apply -f bookinfo/networking/virtual-service-all-v1.yaml -n $PROJECT && \
oc apply -f bookinfo/networking/virtual-service-reviews-test-v2.yaml -n $PROJECT && \
oc apply -f bookinfo/networking/virtual-service-ratings-test-delay.yaml -n $PROJECT
```
El usuario "redhat" debería experimentar una demora de 7 segundos; sin embargo, hay tiempos de espera (timeout) codificados en los microservicios que han provocado que el servicio reviews falle.

- entre el servicio de reviews y ratings está codificado en 10s. 
- entre la página del producto y el servicio de reviews, está codificado como 3 segundos + 1 reintento (un total de 6 segundos). Como resultado, la llamada de la página del producto para revisar se agota prematuramente y arroja un error después de 6 segundos.

Internamente, el servicio reviews:v3 ya reduce el tiempo de espera de reviews a ratings de 10 segundos a 2,5 segundos.
Entonces, si migramos todo el tráfico a reviews:v3 y bajamos la demora de 7s a 2s, la aplicación vuelve al funcionar correctamente.


Finalmente, eliminamos las reglas de enrutamiento de aplicaciones:
```sh
oc apply -f bookinfo/networking/virtual-service-all-v1.yaml -n $PROJECT 
```

## Inyectar una falla

Ahora crearemos una falla en el servicio details para que retorne un error HTTP 500.
```sh
oc apply -f bookinfo/networking/virtual-service-all-v1.yaml -n $PROJECT && \
oc apply -f bookinfo/networking/virtual-service-reviews-test-v2.yaml -n $PROJECT && \
oc apply -f bookinfo/networking/fault-injection-details-v1.yaml
```

Verificamos el error y volvemos al estado anterior:
```sh
oc apply -f bookinfo/networking/destination-rule-all.yaml -n $PROJECT && \
oc apply -f bookinfo/networking/virtual-service-all-v1.yaml -n $PROJECT
```

# Timeout

El tiempo de espera (timeout) evita que la ejecución espere para siempre.

Primero redireccionamos el tráfico a reviews:v2 y agregamos una demora en la 
respuesta de ratings.

```sh
oc apply -f bookinfo/networking/virtual-service-reviews-v2-timeout.yaml -n $PROJECT
```

Vefificamos que demora 2 segundos en cargar y mostrarnos las estrellas negras. Editamos virtual-service-reviews-v2-timeout.yaml quitando el comentario del timout) y lo aplicamos.

```sh
oc apply -f bookinfo/networking/virtual-service-reviews-v2-timeout.yaml -n $PROJECT
```

Finalmente volvemos todo a v1.
```sh
oc apply -f bookinfo/networking/virtual-service-all-v1.yaml -n $PROJECT && \
oc apply -f bookinfo/networking/virtual-service-reviews-test-v2.yaml -n $PROJECT
```

# Circuit Breaker

En la arquitectura de microservicios, un servicio generalmente llama a otros servicios para recuperar datos, y existe la posibilidad de que el servicio "downstream" esté inactivo. Puede deberse a una conexión de red lenta, tiempos de espera o una falta de disponibilidad temporal de ese servicio. Por lo tanto, volver a intentar las llamadas puede resolver el problema. Sin embargo, si hay un problema grave en ese microservicio "downstream", no estará disponible durante más tiempo. En ese caso, la solicitud se enviará continuamente a ese servicio, ya que el cliente no tiene ningún conocimiento sobre la caída de un servicio en particular.

Con la ayuda de este patrón, el cliente invocará un servicio remoto a través de un proxy. Este proxy se comportará básicamente como un disyuntor eléctrico. Entonces, cuando el número de fallas definido supera el número del umbral, el disyuntor del circuito se dispara por un período de tiempo particular. Luego, todos los intentos de invocar el servicio remoto fallarán dentro de este período de tiempo de espera. Una vez que expira el tiempo de espera, el disyuntor permite que pase una cantidad limitada de solicitudes de prueba. Si todas esas solicitudes tienen éxito, el disyuntor vuelve a la normalidad. De lo contrario, si hay una falla, el período de tiempo de espera comienza nuevamente.

Desplegamos dos aplicaciones (httpbin y fortio) y especificamos una DR:

```sh
oc apply -f httpbin/destination-rule-cb.yaml -n $PROJECT && \
oc apply -f httpbin/httpbin-fortio.yaml -n $PROJECT
```

Verificamos el despliege y luego almacenamos el nombre del pod de fortio en la variable FORTIO_POD:

```sh
echo "export FORTIO_POD=$(oc get pods -l app=fortio -o 'jsonpath={.items[0].metadata.name}')" >> $HOME/.bashrc
source $HOME/.bashrc
echo $FORTIO_POD
```

Ingresamos al cliente del pod de fortio y llamamos a httpbin:
```sh
oc exec "$FORTIO_POD" -c fortio -- /usr/bin/fortio curl -quiet http://httpbin:8000/get
```

En la configuración de DestinationRule hemos especificado maxConnections: 1 y http1MaxPendingRequests: 1. Estas reglas indican que si supera más de una conexión, debería ver algunas fallas (abre el circuito). Llameremos al servicio con dos conexiones simultáneas (-c 2) y 20 solicitudes (-n 20):

```sh
oc exec "$FORTIO_POD" -c fortio -- /usr/bin/fortio load -c 2 -qps 0 -n 20 -loglevel Warning http://httpbin:8000/get
```

Al final de la salida veremos valores similares a estos:
```
Code 200 : 17 (85.0 %)
Code 503 : 3 (15.0 %)
```
La mayoría de las solicitudes respondieron OK.

Ahora llameremos al servicio con tres conexiones simultáneas (-c 3) y 30 solicitudes (-n 30):
```sh
oc exec "$FORTIO_POD" -c fortio -- /usr/bin/fortio load -c 3 -qps 0 -n 30 -loglevel Warning http://httpbin:8000/get
```

Ahora empezamos a ver el comportamiento de apertura del circuito esperado.

Por último eliminamos lo agregado para esta prueba:

```sh
oc delete destinationrule httpbin -n $PROJECT && \
oc delete -f httpbin/httpbin-fortio.yaml -n $PROJECT
```

# Espejado de tráfico

El espejado de tráfico (mirroring), también llamado shadowing, permite llevar cambios a producción con el menor riesgo posible, enviando una copia del tráfico en vivo a un servicio duplicado. El tráfico duplicado ocurre fuera de la banda de la ruta de solicitud crítica para el servicio principal.

Además, es importante tener en cuenta que estas solicitudes se reflejan como "disparar y olvidar", lo que significa que las respuestas se descartan.

```sh
oc apply -f bookinfo/networking/virtual-service-reviews-v1-mirror-v2.yaml -n $PROJECT
```

Verificamos en el gráfico de Kiali que empieza a haber tráfico en reviews v2.

Finalmente volvemos todo a v1.
```sh
oc apply -f bookinfo/networking/virtual-service-all-v1.yaml -n $PROJECT && \
oc apply -f bookinfo/networking/virtual-service-reviews-test-v2.yaml -n $PROJECT
```
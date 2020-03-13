// tag::copyright[]
/*******************************************************************************
 * Copyright (c) 2018, 2020 IBM Corporation and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *     IBM Corporation - Initial implementation
 *******************************************************************************/
// end::copyright[]
package it.io.openliberty.guides.inventory;

import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.SSLSession;
import javax.ws.rs.client.Client;
import javax.ws.rs.client.ClientBuilder;
import javax.ws.rs.core.Response;
import javax.json.JsonObject;
import javax.ws.rs.core.MediaType;

import org.apache.cxf.jaxrs.provider.jsrjsonp.JsrJsonpProvider;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

public class InventoryEndpointIT {

    private static String invUrl;
    private static String sysUrl;
    private static String sysKubeService;

    private Client client;
    private Response response;

    @BeforeAll
    public static void oneTimeSetup() {
        String clusterIp = System.getProperty("test.cluster.ip");
        String invNodePort = System.getProperty("test.inventory.node.port");
        String sysNodePort = System.getProperty("test.system.node.port");
        
        sysKubeService = System.getProperty("test.system.kube.service");
        invUrl = "http://" + clusterIp + ":" + invNodePort + "/inventory/systems/";
        sysUrl = "http://" + clusterIp + ":" + sysNodePort + "/system/properties/";
    }

    @BeforeEach
    public void setup() {
        response = null;
        client = ClientBuilder.newBuilder()
                    .hostnameVerifier(new HostnameVerifier() {
                        public boolean verify(String hostname, SSLSession session) {
                            return true;
                        }
                    })
                    .build();

        client.register(JsrJsonpProvider.class);
        client.target(invUrl + "reset").request().post(null);
    }

    @AfterEach
    public void teardown() {
        client.close();
    }

    // tag::tests[]
    // tag::testSuite[]
    @Test
    public void testSuite() {
        this.testEmptyInventory();
        this.testHostRegistration();
        this.testSystemPropertiesMatch();
        this.testUnknownHost();
    }
    // end::testSuite[]

    // tag::testEmptyInventory[]
    public void testEmptyInventory() {
        Response response = this.getResponse(invUrl);
        this.assertResponse(invUrl, response);

        JsonObject obj = response.readEntity(JsonObject.class);

        int expected = 0;
        int actual = obj.getInt("total");
        assertEquals(expected, actual, "The inventory should be empty on application start but it wasn't");

        response.close();
    }
    // end::testEmptyInventory[]

    // tag::testHostRegistration[]
    public void testHostRegistration() {
        this.visitSystemService();

        Response response = this.getResponse(invUrl);
        this.assertResponse(invUrl, response);

        JsonObject obj = response.readEntity(JsonObject.class);

        int expected = 1;
        int actual = obj.getInt("total");
        assertEquals(expected, actual, "The inventory should have one entry for " + sysKubeService);

        boolean serviceExists = obj.getJsonArray("systems").getJsonObject(0)
                                    .get("hostname").toString()
                                    .contains(sysKubeService);
        assertTrue(serviceExists, "A host was registered, but it was not " + sysKubeService);

        response.close();
    }
    // end::testHostRegistration[]

    // tag::testSystemPropertiesMatch[]
    public void testSystemPropertiesMatch() {
        Response invResponse = this.getResponse(invUrl);
        Response sysResponse = this.getResponse(sysUrl);

        this.assertResponse(invUrl, invResponse);
        this.assertResponse(sysUrl, sysResponse);

        JsonObject jsonFromInventory = (JsonObject) invResponse.readEntity(JsonObject.class)
                                                            .getJsonArray("systems")
                                                            .getJsonObject(0)
                                                            .get("properties");

        JsonObject jsonFromSystem = sysResponse.readEntity(JsonObject.class);

        String osNameFromInventory = jsonFromInventory.getString("os.name");
        String osNameFromSystem = jsonFromSystem.getString("os.name");
        this.assertProperty("os.name", sysKubeService, osNameFromSystem,
                            osNameFromInventory);

        String userNameFromInventory = jsonFromInventory.getString("user.name");
        String userNameFromSystem = jsonFromSystem.getString("user.name");
        this.assertProperty("user.name", sysKubeService, userNameFromSystem,
                            userNameFromInventory);

        invResponse.close();
        sysResponse.close();
    }
    // end::testSystemPropertiesMatch[]

    // tag::testUnknownHost[]
    public void testUnknownHost() {
        Response response = this.getResponse(invUrl);
        this.assertResponse(invUrl, response);

        Response badResponse = client.target(invUrl + "badhostname")
            .request(MediaType.APPLICATION_JSON)
            .get();

        String obj = badResponse.readEntity(String.class);

        boolean isError = obj.contains("ERROR");
        assertTrue(isError, "badhostname is not a valid host but it didn't raise an error");

        response.close();
        badResponse.close();
    }

    // end::testUnknownHost[]
    // end::tests[]
    // tag::helpers[]
    // tag::javadoc[]
    /**
     * <p>
     * Returns response information from the specified URL.
     * </p>
     * 
     * @param url
     *          - target URL.
     * @return Response object with the response from the specified URL.
     */
    // end::javadoc[]
    private Response getResponse(String url) {
        return client.target(url).request().get();
    }

    // tag::javadoc[]
    /**
     * <p>
     * Asserts that the given URL has the correct response code of 200.
     * </p>
     * 
     * @param url
     *          - target URL.
     * @param response
     *          - response received from the target URL.
     */
    // end::javadoc[]
    private void assertResponse(String url, Response response) {
        assertEquals(200, response.getStatus(), "Incorrect response code from " + url);
    }

    // tag::javadoc[]
    /**
     * Asserts that the specified JVM system property is equivalent in both the
     * system and inventory services.
     * 
     * @param propertyName
     *          - name of the system property to check.
     * @param hostname
     *          - name of JVM's host.
     * @param expected
     *          - expected name.
     * @param actual
     *          - actual name.
     */
    // end::javadoc[]
    private void assertProperty(String propertyName, String hostname,
        String expected, String actual) {
        assertEquals(expected, actual,
                "JVM system property [" + propertyName + "] "
                        + "in the system service does not match the one stored in "
                        + "the inventory service for " + hostname);
    }

    // tag::javadoc[]
    /**
     * Makes a simple GET request to inventory/localhost.
     */
    // end::javadoc[]
    private void visitSystemService() {
        Response response = this.getResponse(sysUrl);
        this.assertResponse(sysUrl, response);
        response.close();

        Response targetResponse = client
            .target(invUrl + sysKubeService)
            .request()
            .get();

        targetResponse.close();
    }

}

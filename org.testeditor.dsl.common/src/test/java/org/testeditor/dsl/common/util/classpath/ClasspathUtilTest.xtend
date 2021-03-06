/*******************************************************************************
 * Copyright (c) 2012 - 2018 Signal Iduna Corporation and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 * 
 * Contributors:
 * Signal Iduna Corporation - initial API and implementation
 * akquinet AG
 * itemis AG
 *******************************************************************************/
package org.testeditor.dsl.common.util.classpath

import com.google.inject.Guice
import java.io.File
import java.nio.file.Files
import java.util.List
import org.eclipse.core.runtime.IPath
import org.eclipse.core.runtime.Path
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.InternalEObject
import org.junit.Ignore
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.mockito.InjectMocks
import org.testeditor.dsl.common.testing.AbstractTest

import static org.junit.Assume.*
import static org.mockito.Mockito.*

class ClasspathUtilTest extends AbstractTest {

	@InjectMocks
	ClasspathUtil classpathUtil
	@Rule public TemporaryFolder tempFolder = new TemporaryFolder();

	@Ignore
	@Test
	def void intTestGetBuildToolClasspathEntryWithGradle() {
		assumeTrue(new GradleServerConnectUtil().canConnect)
		
		// given
		val gradleBuildFile = tempFolder.newFile("build.gradle")
		val packageDir = new File(tempFolder.newFolder("src"), "/test/java/package")
		packageDir.mkdirs

		Files.write(gradleBuildFile.toPath, getGradleBuildFileExample.bytes)
		val intClasspathUtil = Guice.createInjector.getInstance(ClasspathUtil)

		// when
		val result = intClasspathUtil.getBuildToolClasspathEntry(new Path(packageDir.toString))

		// then
		assertEquals(new Path(tempFolder.root + "/src/test/java"), result)
	}

	def private String getGradleBuildFileExample() {
		'''
			plugins {
			    id 'org.testeditor.gradle-plugin' version '0.6'
			    id 'maven'
			    id 'eclipse'
			}
			
			group = 'org.testeditor.demo'
			version = '1.0.0-SNAPSHOT'
			
			// In this section you declare where to find the dependencies of your project
			repositories {
			    jcenter()
			    maven { url "http://dl.bintray.com/test-editor/Fixtures" }
			    maven { url "http://dl.bintray.com/test-editor/test-editor-maven/" }
			}
			
			// Configure the testeditor plugin
			testeditor {
				version '1.1.0'
			}
			
			// In this section you declare the dependencies for your production and test code
			dependencies {
			    testCompile 'junit:junit:4.12'
			}
		'''
	}

	@Test
	def void testGetBuildProjectBaseDir() {
		// given
		val path = getPathForBuildFileSearch(#[])
		val basePathWithPom = getPathForBuildFileSearch(#["pom.xml"])
		val basePathWithGradle = getPathForBuildFileSearch(#["build.gradle"])

		// when
		val buildScriptNotFound = classpathUtil.getBuildProjectBaseDir(path)
		val pathWithPom = classpathUtil.getBuildProjectBaseDir(basePathWithPom)
		val pathWithGradle = classpathUtil.getBuildProjectBaseDir(basePathWithGradle)

		// then
		assertNull(buildScriptNotFound)
		assertSame(basePathWithPom, pathWithPom)
		assertSame(basePathWithGradle, pathWithGradle)
	}
	
	@Test
	def void testInferPackageForTestCase() {
		// given
		val eObject = mock(InternalEObject)
		when(eObject.eProxyURI).thenReturn(URI.createURI('src/test/java/org/testeditor/Some.tcl'))
		
		val result = classpathUtil.inferPackage(eObject)
		
		result.assertEquals('org.testeditor')
	}
	
	@Test
	def void testInferPackageForFixture() {
		// given
		val eObject = mock(InternalEObject)
		when(eObject.eProxyURI).thenReturn(URI.createURI('src/main/java/org/testeditor/fixtures/HftFixture.java'))
		
		val result = classpathUtil.inferPackage(eObject)
		
		result.assertEquals('org.testeditor.fixtures')
	}
	
	@Test
	def void testValidPackageForPath() {
		// given
		val classpath = new Path('/resource/project-name/src/main/java')
		val path = classpath.append('some/more/package')

		// when
		val package = classpathUtil.packageForPath(path, classpath)

		// then
		package.assertEquals("some.more.package")
	}

	@Test
	def void testValidDefaultPackageForPath() {
		// given
		val classpath = new Path('/resource/project-name/src/main/java')
		val path = classpath

		// when
		val package = classpathUtil.packageForPath(path, classpath)

		// then
		package.assertEquals("")
	}

	@Test(expected=RuntimeException)
	def void testInvalidPackageForPath() {
		// given
		val classpath = new Path('/resource/project-name/src/main/java')
		val path = new Path('/resource/project-name/DIFFERENT/main/java/some/more/package')

		// when
		classpathUtil.packageForPath(path, classpath)

		// then (expect exception)
	}

	def IPath getPathForBuildFileSearch(List<String> objects) {
		val path = mock(IPath)
		val folder = mock(File)
		when(path.toFile).thenReturn(folder)
		when(folder.list).thenReturn(objects)
		when(folder.parent).thenReturn(null)
		return path
	}

}

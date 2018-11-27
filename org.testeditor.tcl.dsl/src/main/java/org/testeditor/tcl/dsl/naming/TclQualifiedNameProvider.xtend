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
package org.testeditor.tcl.dsl.naming

import javax.inject.Inject
import javax.inject.Singleton
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.xbase.scoping.XbaseQualifiedNameProvider
import org.testeditor.dsl.common.util.classpath.ClasspathUtil
import org.testeditor.tcl.TclModel
import org.eclipse.emf.ecore.EObject
import org.testeditor.tcl.TestCase
import org.eclipse.xtext.EcoreUtil2

@Singleton
class TclQualifiedNameProvider extends XbaseQualifiedNameProvider {

	@Inject ClasspathUtil classpathUtil


	override QualifiedName getFullyQualifiedName(EObject obj) {
		if (obj instanceof TestCase) {
			if (obj.name === null) {
				val name = obj.eResource.URI.trimFileExtension.lastSegment
				return qualifiedName(EcoreUtil2.getContainerOfType(obj, TclModel)).append(name)
			} 
		}
		return super.getFullyQualifiedName(obj)
	}

	def QualifiedName qualifiedName(TclModel model) {
		if (model.package === null) {
			val derivedPackage = classpathUtil.inferPackage(model)
			if (derivedPackage.nullOrEmpty) {
				return null
			} else {
				return converter.toQualifiedName(derivedPackage)
			}
		} else {
			return converter.toQualifiedName(model.package)
		}
	}

}

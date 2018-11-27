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
package org.testeditor.tsl.dsl.naming

import javax.inject.Inject
import javax.inject.Singleton
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.xbase.scoping.XbaseQualifiedNameProvider
import org.testeditor.dsl.common.util.classpath.ClasspathUtil
import org.testeditor.tsl.TestSpecification
import org.testeditor.tsl.TslModel

@Singleton
class TslQualifiedNameProvider extends XbaseQualifiedNameProvider {

	@Inject ClasspathUtil classpathUtil

	override QualifiedName getFullyQualifiedName(EObject obj) {
		if (obj instanceof TestSpecification) {
			if (obj.name === null) {
				val name = obj.eResource.URI.trimFileExtension.lastSegment
				val model = EcoreUtil2.getContainerOfType(obj, TslModel)
				val derivedPackage = classpathUtil.inferPackage(model)
				if (derivedPackage.nullOrEmpty) {
					return QualifiedName.create(name)
				} else {
					return qualifiedName(model).append(name)
				}
			}
		}
		return super.getFullyQualifiedName(obj)
	}

	def QualifiedName qualifiedName(TslModel model) {
		if (model.package === null) {
			val derivedPackage = classpathUtil.inferPackage(model)
			if (derivedPackage.nullOrEmpty) {
				return null // no qualified (package) name available
			} else {
				return converter.toQualifiedName(derivedPackage)
			}
		}
		return converter.toQualifiedName(model.package)
	}

}

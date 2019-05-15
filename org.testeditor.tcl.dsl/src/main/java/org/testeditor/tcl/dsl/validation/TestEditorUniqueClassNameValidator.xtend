package org.testeditor.tcl.dsl.validation

import javax.inject.Inject
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.common.types.JvmDeclaredType
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.xbase.jvmmodel.IJvmModelAssociations
import org.eclipse.xtext.xbase.jvmmodel.JvmModelAssociator
import org.eclipse.xtext.xbase.jvmmodel.JvmModelAssociator.Adapter
import org.eclipse.xtext.xbase.validation.IssueCodes
import org.eclipse.xtext.xbase.validation.UniqueClassNameValidator
import org.testeditor.aml.Component
import org.testeditor.aml.ComponentElementType
import org.testeditor.aml.ComponentType
import org.testeditor.aml.InteractionType
import org.testeditor.aml.ValueSpace
import org.testeditor.tcl.TestCase
import org.testeditor.tcl.TestConfiguration

/**
 * Generates error-level validation issues with user-comprehensible messages if the same name 
 * is used for more than one model element from which Java types are generated.
 * 
 * Currently, Java classes or interfaces are generated from test cases and test frames (TCL),
 * as well as value spaces, interaction types, component element types, component types, and
 * components (AML). If any two of these have the same name (fully-qualified, i.e. they are also 
 * in the same package), this class generates an error, just as the base class implementing the
 * generic, default behavior would do. 
 * However, this class is meant to produce error messages that are more concrete, by referring
 * to the actual Test-Editor concepts being affected, and that indicate what needs to be done
 * to remedy the problem.
 */
class TestEditorUniqueClassNameValidator extends UniqueClassNameValidator {

	@Inject IJvmModelAssociations associations
	
	static val readableTypeNames = #{ TestCase -> 'test case', TestConfiguration -> 'test frame', 
		ValueSpace -> 'value space', InteractionType -> 'interaction type', ComponentElementType -> 'component element type', ComponentType -> 'component type', Component -> 'component'
	}

	override protected checkUniqueInIndex(JvmDeclaredType type, Iterable<IEObjectDescription> descriptions) {
		val typeName = readableTypeNames.getOrDefault(type.associatedModelElementType, 'model element')
		val otherType = descriptions.map[(it.EObjectOrProxy as JvmDeclaredType)].reject[it === type].head.associatedModelElementType
		val otherTypeName = readableTypeNames.getOrDefault(otherType, 'model element')
		
		val resourceURIs = descriptions.map[EObjectURI.trimFragment].toSet
		if (resourceURIs.size > 1) {
			val fileName = resourceURIs.filter[it != type.eResource.URI].head.lastSegment
			addIssue(type, fileName, message(type, fileName, typeName, otherTypeName))
			return false
		} else {
			// There is more than one description in one single file -> local duplication
			if(descriptions.size > 1){
				addIssue(type)
				return false
			}
		}
		return true
	}

	protected def void addIssue(JvmDeclaredType type, String fileName, String message) {
		val sourceElement = associations.getPrimarySourceElement(type)
		if (sourceElement === null)
			addIssue(message, type, IssueCodes.DUPLICATE_TYPE)
		else {
			val feature = sourceElement.eClass.getEStructuralFeature('name')
			addIssue(message, sourceElement, feature, IssueCodes.DUPLICATE_TYPE)
		}
	}

	private def String message(JvmDeclaredType type, String fileName, String typeName, String otherTypeName) {
		return '''There is already a(n) «otherTypeName» named '«type.simpleName»' in this package«IF fileName !== null» defined in «fileName»«ENDIF». ''' +
		'''«IF (typeName == otherTypeName)»Either rename or move«ELSE»Rename either this «typeName» or the «otherTypeName», or move either«ENDIF» one to a different package.'''
	}	
	
	private def Class<?> getAssociatedModelElementType(JvmDeclaredType type) {
		val jvmModelAssociator = EcoreUtil2.getExistingAdapter(type.eResource, Adapter)
		return if (jvmModelAssociator instanceof JvmModelAssociator.Adapter) {
			val modelElementTypes = jvmModelAssociator.targetToSourceMap.get(type)
			readableTypeNames.keySet.filter[modelElementTypes.exists[modelElementType|isInstance(modelElementType)]].head
		} else {
			null
		}
	}

}


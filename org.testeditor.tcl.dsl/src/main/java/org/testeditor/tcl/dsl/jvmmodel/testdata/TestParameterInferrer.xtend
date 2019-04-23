package org.testeditor.tcl.dsl.jvmmodel.testdata

import com.google.gson.JsonElement
import com.google.gson.JsonObject
import java.util.Map
import java.util.Set
import javax.inject.Inject
import javax.inject.Singleton
import org.eclipse.xtext.common.types.JvmMember
import org.eclipse.xtext.common.types.JvmTypeReference
import org.eclipse.xtext.common.types.JvmVisibility
import org.eclipse.xtext.xbase.compiler.output.ITreeAppendable
import org.eclipse.xtext.xbase.jvmmodel.JvmTypeReferenceBuilder
import org.eclipse.xtext.xbase.jvmmodel.JvmTypesBuilder
import org.testeditor.tcl.AssignmentVariable
import org.testeditor.tcl.TestParameter

@Singleton
class TestParameterInferrer {

	@Inject extension JvmTypesBuilder
	
	// map instead of set of dispatch methods, to also be able to report the types that can be handled
	// (without reflection or other magic) 
	var Map<String, (AssignmentVariable, TestParameter)=>CharSequence> _initializerForType
	
	def Set<String> getKnownTypes(JvmTypeReferenceBuilder it) {
		return initializerForType.keySet
	}

	/**
	 * Create a field for a test parameter, derived from a main parameter.
	 * The way the derived parameter is initialized depends on the type of the main parameter.
	 * This method cannot recover if it does not know the type of the main parameter
	 */
	def JvmMember createDerivedTestParameter(TestParameter parameter, AssignmentVariable mainParameter, JvmTypeReference mainParameterType, JvmTypeReferenceBuilder it) {
		return parameter.toField(parameter.name, typeRef(Object)) => [ visibility = JvmVisibility.PRIVATE ]
	}
	
	def (ITreeAppendable)=>void initializeTestParameters(TestParameter parameter, AssignmentVariable mainParameter, JvmTypeReference mainParameterType, JvmTypeReferenceBuilder it) {
		return [output|
			output.append('''«parameter.name» = «initializerForType.get(mainParameterType.identifier)?.apply(mainParameter, parameter)»;''').newLine
			
		]
	}
	
	// init lazily, because eager init will somehow break injection.
	private def getInitializerForType(JvmTypeReferenceBuilder it) {
		if (_initializerForType === null) {
			_initializerForType = #{
				typeRef(JsonElement).identifier -> [AssignmentVariable mainParameter, TestParameter parameter|
					'''«mainParameter.name».getAsJsonObject().get("«parameter.name»")'''
				],
				typeRef(Map, typeRef(String), wildcard).identifier -> [AssignmentVariable mainParameter, TestParameter parameter|
					'''«mainParameter.name».get("«parameter.name»")'''
				],
				typeRef(JsonObject).identifier -> [AssignmentVariable mainParameter, TestParameter parameter|
					'''«mainParameter.name».get("«parameter.name»")'''
				]
//add support for additional types like so:
//				,
//				typeRef(<TYPE_STRING>) -> [AssignmentVariable mainParameter, TestParameter parameter|
//					template = <TEMPLATE>
//				]
			}
		}
		return _initializerForType
	}
}

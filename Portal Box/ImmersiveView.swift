//
//  ImmersiveView.swift
//  Portal Box
//
//  Created by Rotem Cohen on 5/28/25.
//

import SwiftUI
import RealityKit
import RealityKitContent

@MainActor
struct ImmersiveView: View {

    @State private var box = Entity() // to store our box
    
    var body: some View {
        RealityView { content in
            // Add the initial RealityKit content
            if let scene = try? await Entity(named: "PortalBoxScene", in: realityKitContentBundle) {
                content.add(scene)
                
                // change the position of the box
                guard let box = scene.findEntity(named: "Box") else {
                    fatalError()
                }
                self.box = box
                box.position = [0, 1, -2] // meters
                box.scale *= [1,2,1] // make taller
                
                let world1Portal = await createWorldPortal(
                    texture: "skybox1",
                    anchorName: "AnchorPortal1",
                    particleWorldName: "World1Scene",
                    content: content,
                    scene: scene
                )
                world1Portal.transform.rotation = simd_quatf(angle: .pi/2, axis: [0, 0, -1])
                let world2Portal = await createWorldPortal(
                    texture: "skybox2",
                    anchorName: "AnchorPortal2",
                    particleWorldName: "World2Scene",
                    content: content,
                    scene: scene
                )
                world2Portal.transform.rotation = simd_quatf(angle: .pi/2, axis: [0, 0, 1])

                let world3Portal = await createWorldPortal(
                    texture: "skybox3",
                    anchorName: "AnchorPortal3",
                    particleWorldName: "World3Scene",
                    content: content,
                    scene: scene
                )
                world3Portal.transform.rotation = simd_quatf(angle: .pi/2, axis: [1, 0, 0])

                let world4Portal = await createWorldPortal(
                    texture: "skybox4",
                    anchorName: "AnchorPortal4",
                    particleWorldName: "World4Scene",
                    content: content,
                    scene: scene
                )
                world4Portal.transform.rotation = simd_quatf(angle: .pi/2, axis: [-1, 0, 0])
            }
        }
    }
    
    func createWorldPortal(texture: String, anchorName: String, particleWorldName: String, content: RealityViewContent, scene: Entity) async -> Entity {
        let world = Entity()
        world.components.set(WorldComponent())
        let skybox = await createSkyboxEntity(texture: texture)
        world.addChild(skybox)
        if let particleWorld = try? await Entity(named: particleWorldName, in: realityKitContentBundle) {
            particleWorld.position = [0, 3, 0]
            world.addChild(particleWorld)
        }
        
        content.add(world)
        
        let worldPortal = createPortal(target: world)
        content.add(worldPortal)
        
        guard let anchorPortal = scene.findEntity(named: anchorName) else {
            fatalError("Cannot find portal anchor")
        }
        
        anchorPortal.addChild(worldPortal)
        return worldPortal
    }
    
    func createPortal(target: Entity) -> Entity {
        let portalMesh = MeshResource.generatePlane(width: 1, depth: 1) // meters
        let portal = ModelEntity(mesh: portalMesh, materials: [PortalMaterial()])
        portal.components.set(PortalComponent(target: target))
        return portal
    }
    
    func createSkyboxEntity(texture: String) async -> Entity {
        guard let resource = try? await TextureResource(named: texture) else {
            fatalError("Unable to load the skybox")
        }
        
        var material = UnlitMaterial()
        material.color = .init(texture: .init(resource))
        
        let entity = Entity()
        entity.components.set(ModelComponent(
            mesh: .generateSphere(radius: 1000),
            materials: [material]
        ))
        entity.scale *= .init(x: -1, y: 1, z: 1) //inverse texture
        return entity
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
